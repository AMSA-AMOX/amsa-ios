import { NextResponse, after } from "next/server";
import { verifyToken } from "@/lib/auth";
import { supabase } from "@/lib/supabase";
import {
  membershipToProfileUpdates,
  normalizeMembershipSubmissionPayload,
  validateMembershipSubmissionPayload,
} from "@/lib/membership";
import { emailDomainLabel, verifySchoolEmail } from "@/lib/college-match";
import { resolveUserDenorm } from "@/lib/user-denorm";
import { pushNewApplication } from "@/lib/push";

const MEMBERSHIP_COLUMNS = `
  id,
  user_id,
  created_at,
  full_name,
  pronouns,
  enrolled_university,
  year_in_school,
  state,
  city,
  major,
  expected_graduation,
  email,
  social_media,
  phone,
  career_interests,
  career_interests_other,
  amsa_interests,
  amsa_interests_other,
  mentorship_interest,
  event_ideas,
  heard_about_amsa,
  heard_about_amsa_other,
  agrees_to_emails,
  review_status,
  reviewed_at,
  reviewed_by,
  assigned_role,
  admin_note
`;

type MembershipRow = {
  id: string;
  user_id: number;
  created_at: string;
  full_name: string;
  pronouns: string | null;
  enrolled_university: string;
  year_in_school: string;
  state: string;
  city: string;
  major: string;
  expected_graduation: string;
  email: string;
  social_media: string;
  phone: string;
  career_interests: string[] | null;
  career_interests_other: string | null;
  amsa_interests: string[] | null;
  amsa_interests_other: string | null;
  mentorship_interest: string;
  event_ideas: string | null;
  heard_about_amsa: string;
  heard_about_amsa_other: string | null;
  agrees_to_emails: boolean;
  review_status: string;
  reviewed_at: string | null;
  reviewed_by: number | null;
  assigned_role: string | null;
  admin_note: string | null;
};

function toClientPayload(row: MembershipRow) {
  return {
    id: row.id,
    userId: row.user_id,
    createdAt: row.created_at,
    fullName: row.full_name,
    pronouns: row.pronouns ?? "",
    enrolledUniversity: row.enrolled_university,
    yearInSchool: row.year_in_school,
    state: row.state,
    city: row.city,
    major: row.major,
    expectedGraduation: row.expected_graduation,
    email: row.email,
    socialMedia: row.social_media,
    phone: row.phone,
    careerInterests: row.career_interests ?? [],
    careerInterestsOther: row.career_interests_other ?? "",
    amsaInterests: row.amsa_interests ?? [],
    amsaInterestsOther: row.amsa_interests_other ?? "",
    mentorshipInterest: row.mentorship_interest,
    eventIdeas: row.event_ideas ?? "",
    heardAboutAmsa: row.heard_about_amsa,
    heardAboutAmsaOther: row.heard_about_amsa_other ?? "",
    agreesToEmails: row.agrees_to_emails,
    reviewStatus: row.review_status,
    reviewedAt: row.reviewed_at,
    reviewedBy: row.reviewed_by,
    assignedRole: row.assigned_role,
    adminNote: row.admin_note ?? "",
  };
}

export async function GET(request: Request) {
  let payload;
  try {
    payload = verifyToken(request);
  } catch (res) {
    return res as NextResponse;
  }

  try {
    const { data: membership, error } = await supabase
      .from("amsa_memberships")
      .select(MEMBERSHIP_COLUMNS)
      .eq("user_id", payload.id)
      .maybeSingle<MembershipRow>();

    if (error) throw error;
    return NextResponse.json({ membership: membership ? toClientPayload(membership) : null });
  } catch (error) {
    console.error("GET /api/user/verification failed:", error);
    return NextResponse.json({ message: "Failed to load verification form" }, { status: 500 });
  }
}

export async function POST(request: Request) {
  let payload;
  try {
    payload = verifyToken(request);
  } catch (res) {
    return res as NextResponse;
  }

  try {
    const body = await request.json();
    const normalized = normalizeMembershipSubmissionPayload(body);
    const validation = validateMembershipSubmissionPayload(normalized);

    if (!validation.ok) {
      return NextResponse.json(
        { message: "Invalid verification payload", errors: validation.errors },
        { status: 400 },
      );
    }

    // The .edu email must belong to the university the applicant named. When
    // it does, use the official college name so the profile and college pages
    // line up. If the domain isn't in our colleges table we can't tell — let
    // it through for admins to review.
    const emailCheck = await verifySchoolEmail(normalized.email, normalized.enrolledUniversity);
    if (emailCheck.status === "mismatch") {
      return NextResponse.json(
        {
          message: `Your school email (${emailDomainLabel(normalized.email)}) belongs to ${emailCheck.college.name}, but you entered "${normalized.enrolledUniversity}". Please use an email from that university or correct the university name.`,
          college: emailCheck.college,
        },
        { status: 400 },
      );
    }
    if (emailCheck.status === "match") {
      normalized.enrolledUniversity = emailCheck.college.name;
    }

    const { data: existing, error: existingError } = await supabase
      .from("amsa_memberships")
      .select("id, review_status")
      .eq("user_id", payload.id)
      .maybeSingle<{ id: string; review_status: string }>();

    if (existingError) throw existingError;
    if (existing?.review_status === "approved") {
      return NextResponse.json(
        { message: "This verification form has already been approved." },
        { status: 409 },
      );
    }

    const upsertPayload = {
      user_id: payload.id,
      full_name: normalized.fullName,
      pronouns: normalized.pronouns || null,
      enrolled_university: normalized.enrolledUniversity,
      year_in_school: normalized.yearInSchool,
      state: normalized.state,
      city: normalized.city,
      major: normalized.major,
      expected_graduation: normalized.expectedGraduation,
      email: normalized.email,
      social_media: normalized.socialMedia,
      phone: normalized.phone,
      career_interests: normalized.careerInterests,
      career_interests_other: normalized.careerInterestsOther || null,
      amsa_interests: normalized.amsaInterests,
      amsa_interests_other: normalized.amsaInterestsOther || null,
      mentorship_interest: normalized.mentorshipInterest,
      event_ideas: normalized.eventIdeas || null,
      heard_about_amsa: normalized.heardAboutAmsa,
      heard_about_amsa_other: normalized.heardAboutAmsaOther || null,
      agrees_to_emails: normalized.agreesToEmails,
      review_status: "pending",
      reviewed_at: null,
      reviewed_by: null,
      assigned_role: null,
      admin_note: null,
    };

    let membership: MembershipRow | null = null;

    if (existing?.id) {
      const { data: updated, error: updateError } = await supabase
        .from("amsa_memberships")
        .update(upsertPayload)
        .eq("id", existing.id)
        .select(MEMBERSHIP_COLUMNS)
        .single<MembershipRow>();

      if (updateError || !updated) {
        throw updateError || new Error("Verification update failed");
      }
      membership = updated;
    } else {
      const { data: created, error: insertError } = await supabase
        .from("amsa_memberships")
        .insert(upsertPayload)
        .select(MEMBERSHIP_COLUMNS)
        .single<MembershipRow>();

      if (insertError || !created) {
        throw insertError || new Error("Verification create failed");
      }
      membership = created;
    }

    // Immediately carry the application details over to the user's profile
    // (school, year, major, graduation, location, phone, .edu email) so they
    // don't have to re-enter them on the Profile page.
    const profileUpdates = membershipToProfileUpdates(normalized);
    const { error: profileError } = await supabase
      .from("Users")
      .update({
        ...profileUpdates,
        ...(await resolveUserDenorm({
          schoolName: profileUpdates.schoolName,
          schoolEmail: profileUpdates.schoolEmail,
          state: profileUpdates.state,
        })),
      })
      .eq("id", payload.id);

    if (profileError) {
      console.error("Profile sync after verification submit failed:", profileError);
    }

    after(() => pushNewApplication(normalized.fullName));

    return NextResponse.json(
      { membership: toClientPayload(membership), college: emailCheck.college },
      { status: 201 },
    );
  } catch (error) {
    console.error("POST /api/user/verification failed:", error);
    return NextResponse.json({ message: "Failed to submit verification form" }, { status: 500 });
  }
}
