import { NextResponse, after } from "next/server";
import { assertRole, ROLES, verifyToken } from "@/lib/auth";
import { MEMBERSHIP_ASSIGNED_ROLES, isProtectedRole } from "@/lib/membership";
import { supabase } from "@/lib/supabase";
import { findCollegeByEmail } from "@/lib/college-match";
import { resolveUserDenorm } from "@/lib/user-denorm";
import { pushMembershipDecision } from "@/lib/push";

type ReviewBody = {
  reviewStatus?: "approved" | "rejected";
  assignedRole?: "us_member" | "member";
  adminNote?: string;
};

export async function PATCH(
  request: Request,
  { params }: { params: Promise<{ id: string }> },
) {
  let payload;
  try {
    payload = verifyToken(request);
    assertRole(payload, ROLES.ADMIN);
  } catch (res) {
    return res as NextResponse;
  }

  try {
    const { id } = await params;
    const body = (await request.json()) as ReviewBody;
    const reviewStatus = body.reviewStatus;
    const assignedRole = body.assignedRole;
    const adminNote = body.adminNote?.trim() || null;

    if (!reviewStatus || !["approved", "rejected"].includes(reviewStatus)) {
      return NextResponse.json({ message: "reviewStatus must be approved or rejected" }, { status: 400 });
    }

    if (reviewStatus === "approved" && !MEMBERSHIP_ASSIGNED_ROLES.includes((assignedRole ?? "") as "us_member" | "member")) {
      return NextResponse.json({ message: "assignedRole must be us_member or member when approving" }, { status: 400 });
    }

    const { data: existing, error: existingError } = await supabase
      .from("amsa_memberships")
      .select("id, user_id, email, enrolled_university, state")
      .eq("id", id)
      .single<{ id: string; user_id: number; email: string; enrolled_university: string | null; state: string | null }>();

    if (existingError || !existing) {
      return NextResponse.json({ message: "Verification submission not found" }, { status: 404 });
    }

    // US Member status requires a verified .edu school email — never approve without one.
    if (reviewStatus === "approved" && !existing.email?.toLowerCase().endsWith(".edu")) {
      return NextResponse.json(
        { message: "Cannot approve: the applicant's school email must end in .edu." },
        { status: 400 },
      );
    }

    const now = new Date().toISOString();
    const membershipUpdates =
      reviewStatus === "approved"
        ? {
            review_status: "approved",
            assigned_role: assignedRole,
            admin_note: adminNote,
            reviewed_at: now,
            reviewed_by: payload.id,
          }
        : {
            review_status: "rejected",
            assigned_role: null,
            admin_note: adminNote,
            reviewed_at: now,
            reviewed_by: payload.id,
          };

    const { error: membershipError } = await supabase
      .from("amsa_memberships")
      .update(membershipUpdates)
      .eq("id", id);

    if (membershipError) throw membershipError;

    // Board members / admins / ambassadors also submit this form, but a review
    // decision must never overwrite their elevated role.
    const { data: applicant, error: applicantError } = await supabase
      .from("Users")
      .select("role")
      .eq("id", existing.user_id)
      .single<{ role: string | null }>();

    if (applicantError) throw applicantError;
    const keepRole = isProtectedRole(applicant?.role);

    // Official college name for the profile, resolved from the verified .edu domain.
    const college =
      reviewStatus === "approved" && existing.email?.endsWith(".edu")
        ? await findCollegeByEmail(existing.email, existing.enrolled_university)
        : null;

    const userUpdates =
      reviewStatus === "approved"
        ? {
            ...(keepRole ? {} : { role: assignedRole }),
            acceptanceStatus: "approved",
            emailVerified: true,
            // Confirm the .edu email (and its college) on the user's profile
            ...(existing.email?.endsWith(".edu") ? { schoolEmail: existing.email } : {}),
            ...(college ? { schoolName: college.name } : {}),
            ...(await resolveUserDenorm({
              schoolName: college?.name ?? existing.enrolled_university,
              schoolEmail: existing.email,
              state: existing.state,
            })),
          }
        : { ...(keepRole ? {} : { role: "member" }), acceptanceStatus: "approved" };

    const { error: userError } = await supabase
      .from("Users")
      .update(userUpdates)
      .eq("id", existing.user_id);

    if (userError) throw userError;

    after(() => pushMembershipDecision(existing.user_id, reviewStatus === "approved"));

    return NextResponse.json({ message: "Verification review saved" });
  } catch (error) {
    console.error("PATCH /api/admin/verification/[id] failed:", error);
    return NextResponse.json({ message: "Failed to update verification review" }, { status: 500 });
  }
}
