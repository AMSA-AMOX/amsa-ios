import { NextResponse } from "next/server";
import { supabase } from "@/lib/supabase";
import { verifyToken } from "@/lib/auth";

// POST /api/user/terms — records that the caller agreed to the Terms of Use
// (members who signed up before the signup checkbox existed).
export async function POST(request: Request) {
  let payload;
  try {
    payload = verifyToken(request);
  } catch (res) {
    return res as NextResponse;
  }

  const termsAcceptedAt = new Date().toISOString();
  const { error } = await supabase.from("Users").update({ termsAcceptedAt }).eq("id", payload.id);
  if (error) {
    console.error("POST /api/user/terms failed:", error);
    return NextResponse.json({ message: "Failed to save. Please try again." }, { status: 500 });
  }
  return NextResponse.json({ termsAcceptedAt });
}
