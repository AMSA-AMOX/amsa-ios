import { NextResponse } from "next/server";
import bcrypt from "bcryptjs";
import { supabase } from "@/lib/supabase";
import { makeToken, isAmsaAdminEmail } from "@/lib/auth";

export async function POST(request: Request) {
  try {
    const body = await request.json();
    const { email, password } = body;
    const normalizedEmail = email?.toLowerCase().trim();

    if (!normalizedEmail || !password) {
      return NextResponse.json(
        { message: "Missing email or password" },
        { status: 400 }
      );
    }

    const { data: user, error } = await supabase
      .from("Users")
      .select("id, email, password, firstName, lastName, role, acceptanceStatus, profilePic, level, bio, graduationYear, termsAcceptedAt")
      .eq("email", normalizedEmail)
      .single();

    if (error || !user) {
      return NextResponse.json(
        { message: "Invalid email or password" },
        { status: 401 }
      );
    }

    const match = await bcrypt.compare(password, user.password);
    if (!match) {
      return NextResponse.json(
        { message: "Invalid email or password" },
        { status: 401 }
      );
    }

    let role = user.role ?? "member";
    let acceptanceStatus = user.acceptanceStatus ?? "approved";

    // Auto-upgrade @amsa.mn emails to board_member and auto-verify them
    if (isAmsaAdminEmail(normalizedEmail) && role !== "admin" && role !== "board_member") {
      role = "board_member";
      acceptanceStatus = "approved";
      await supabase
        .from("Users")
        .update({ role, acceptanceStatus, emailVerified: true })
        .eq("id", user.id);
    } else if (isAmsaAdminEmail(normalizedEmail) && role === "board_member" && acceptanceStatus !== "approved") {
      acceptanceStatus = "approved";
      await supabase
        .from("Users")
        .update({ acceptanceStatus, emailVerified: true })
        .eq("id", user.id);
    } else if (role === "member" && acceptanceStatus !== "approved") {
      acceptanceStatus = "approved";
      await supabase
        .from("Users")
        .update({ acceptanceStatus })
        .eq("id", user.id);
    }

    // Auto-upgrade to alum if their graduation year has passed
    if (role === "member" || role === "us_member" || role === "ambassador") {
      const currentYear = new Date().getFullYear();
      let isAlum = false;

      if (user.graduationYear && user.graduationYear <= currentYear) {
        isAlum = true;
      }

      if (!isAlum) {
        const { data: educations } = await supabase
          .from("Education")
          .select("graduationYear, currentlyEnrolled")
          .eq("userId", user.id)
          .eq("currentlyEnrolled", false)
          .not("graduationYear", "is", null);

        if (educations?.some((e) => e.graduationYear && e.graduationYear <= currentYear)) {
          isAlum = true;
        }
      }

      if (isAlum) {
        role = "alum";
        await supabase.from("Users").update({ role: "alum" }).eq("id", user.id);
      }
    }

    // Compute roles from primary role (admin always gets us_member too)
    const roles = role === "admin" ? ["admin", "us_member"] : [role];

    const token = makeToken({ id: user.id, role });

    return NextResponse.json({
      message: "Login successful",
      user: {
        id: user.id,
        email: normalizedEmail,
        role,
        roles,
        firstName: user.firstName ?? "",
        lastName: user.lastName ?? "",
        acceptanceStatus,
        profilePic: user.profilePic ?? null,
        level: user.level ?? null,
        bio: user.bio ?? null,
        termsAcceptedAt: user.termsAcceptedAt ?? null,
      },
      token,
    });
  } catch (e) {
    console.error(e);
    return NextResponse.json({ message: "Login failed" }, { status: 500 });
  }
}
