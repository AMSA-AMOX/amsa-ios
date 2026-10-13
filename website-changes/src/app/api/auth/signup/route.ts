import { NextResponse, after } from "next/server";
import bcrypt from "bcryptjs";
import { supabase } from "@/lib/supabase";
import { makeToken, isAmsaAdminEmail } from "@/lib/auth";
import { sendWelcomeEmail } from "@/lib/email/resend";

const TURNSTILE_SECRET = process.env.TURNSTILE_SECRET_KEY ?? "";

/** Letters, spaces, hyphens, apostrophes only — no random strings or numbers. */
function isValidName(value: unknown): value is string {
  if (typeof value !== "string") return false;
  const trimmed = value.trim();
  return trimmed.length >= 1 && trimmed.length <= 50 && /^[\p{L}\p{M}' -]+$/u.test(trimmed);
}

async function verifyTurnstile(token: string, ip?: string): Promise<boolean> {
  try {
    const payload: { secret: string; response: string; remoteip?: string } = {
      secret: TURNSTILE_SECRET,
      response: token,
    };
    if (ip) payload.remoteip = ip;

    const res = await fetch("https://challenges.cloudflare.com/turnstile/v0/siteverify", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });
    const data = await res.json();
    if (data.success !== true) {
      console.error("[turnstile] verification failed", data["error-codes"] ?? []);
    }
    return data.success === true;
  } catch {
    return false;
  }
}

export async function POST(request: Request) {
  try {
    const body = await request.json();
    const { email, password, firstName, lastName, turnstileToken, acceptedTerms } = body;

    const eduEmail = email?.toLowerCase().trim();

    if (!eduEmail || !password) {
      return NextResponse.json(
        { message: "Missing email or password" },
        { status: 400 }
      );
    }

    // Agreeing to the Terms of Use (which ban objectionable content) is required.
    if (acceptedTerms !== true) {
      return NextResponse.json(
        { message: "Please agree to the Terms of Use to create an account." },
        { status: 400 }
      );
    }

    // Name validation
    if (!isValidName(firstName) || !isValidName(lastName)) {
      return NextResponse.json(
        { message: "Please enter a valid first and last name." },
        { status: 400 }
      );
    }

    // Turnstile verification (skip only if secret key is not configured, e.g. local dev)
    if (TURNSTILE_SECRET) {
      if (!turnstileToken || typeof turnstileToken !== "string") {
        return NextResponse.json(
          { message: "Security check required." },
          { status: 400 }
        );
      }
      const clientIp =
        request.headers.get("cf-connecting-ip") ??
        request.headers.get("x-forwarded-for")?.split(",")[0]?.trim();
      const valid = await verifyTurnstile(turnstileToken, clientIp);
      if (!valid) {
        return NextResponse.json(
          { message: "Security check failed. Please try again." },
          { status: 400 }
        );
      }
    }

    // Check for existing user
    const { data: existing } = await supabase
      .from("Users")
      .select("id")
      .eq("email", eduEmail)
      .single();

    if (existing) {
      return NextResponse.json(
        { message: "Email already in use" },
        { status: 409 }
      );
    }

    const hashedPassword = await bcrypt.hash(password, 10);
    const isBoardMember = isAmsaAdminEmail(eduEmail);
    const role = isBoardMember ? "board_member" : "member";
    const acceptanceStatus = "approved";
    const emailVerified = isBoardMember;
    const termsAcceptedAt = new Date().toISOString();

    const { data: user, error: userError } = await supabase
      .from("Users")
      .insert({
        email: eduEmail,
        password: hashedPassword,
        firstName,
        lastName,
        role,
        acceptanceStatus,
        emailVerified,
        termsAcceptedAt,
      })
      .select("id, email, firstName, lastName, role, acceptanceStatus")
      .single();

    if (userError || !user) {
      console.error(userError);
      return NextResponse.json({ message: "Signup failed" }, { status: 500 });
    }

    const token = makeToken({ id: user.id, role });

    // Welcome email — sent after the response is flushed so the Resend round
    // trip never adds to signup latency, and can never fail the signup.
    after(() =>
      sendWelcomeEmail({ userEmail: eduEmail, firstName }).catch((emailError) => {
        console.error("Welcome email failed:", emailError);
      }),
    );

    return NextResponse.json(
      {
        message: "Signup successful",
        user: {
          id: user.id,
          email: eduEmail,
          role,
          roles: [role],
          firstName,
          lastName,
          acceptanceStatus,
          profilePic: null,
          level: null,
          bio: null,
          termsAcceptedAt,
        },
        token,
      },
      { status: 201 }
    );
  } catch (e) {
    console.error(e);
    return NextResponse.json({ message: "Signup failed" }, { status: 500 });
  }
}
