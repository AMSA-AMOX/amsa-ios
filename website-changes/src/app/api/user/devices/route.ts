import { NextResponse } from "next/server";
import { supabase } from "@/lib/supabase";
import { verifyToken } from "@/lib/auth";

// APNs device tokens are hex; Apple doesn't promise a fixed length.
const TOKEN_PATTERN = /^[0-9a-f]{32,512}$/i;

async function readToken(request: Request): Promise<{ token: string; environment: string } | null> {
  const body = await request.json().catch(() => null);
  const token = typeof body?.token === "string" ? body.token.trim() : "";
  if (!TOKEN_PATTERN.test(token)) return null;
  return { token, environment: body?.environment === "sandbox" ? "sandbox" : "production" };
}

// POST /api/user/devices { token, environment } — the iOS app registers this device for push
// notifications after sign-in. A device that was signed in to another account moves to this one.
export async function POST(request: Request) {
  let payload;
  try {
    payload = verifyToken(request);
  } catch (res) {
    return res as NextResponse;
  }

  const device = await readToken(request);
  if (!device) return NextResponse.json({ message: "Invalid device token" }, { status: 400 });

  const { error } = await supabase.from("DeviceTokens").upsert(
    {
      token: device.token,
      userId: payload.id,
      platform: "ios",
      environment: device.environment,
      updatedAt: new Date().toISOString(),
    },
    { onConflict: "token" },
  );
  if (error) {
    console.error("POST /api/user/devices failed:", error);
    return NextResponse.json({ message: "Failed to register device" }, { status: 500 });
  }
  return NextResponse.json({ ok: true });
}

// DELETE /api/user/devices { token } — on sign-out, so the device stops getting this member's pushes.
export async function DELETE(request: Request) {
  let payload;
  try {
    payload = verifyToken(request);
  } catch (res) {
    return res as NextResponse;
  }

  const device = await readToken(request);
  if (!device) return NextResponse.json({ message: "Invalid device token" }, { status: 400 });

  const { error } = await supabase.from("DeviceTokens").delete().eq("token", device.token).eq("userId", payload.id);
  if (error) {
    console.error("DELETE /api/user/devices failed:", error);
    return NextResponse.json({ message: "Failed to unregister device" }, { status: 500 });
  }
  return NextResponse.json({ ok: true });
}
