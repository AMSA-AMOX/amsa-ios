import { NextResponse } from "next/server";
import { supabase } from "@/lib/supabase";
import { verifyToken } from "@/lib/auth";

type RouteContext = { params: Promise<{ id: string }> };

// DELETE /api/user/blocks/[id] — unblock a member
export async function DELETE(request: Request, context: RouteContext) {
  let payload;
  try {
    payload = verifyToken(request);
  } catch (res) {
    return res as NextResponse;
  }

  const { id } = await context.params;
  const userId = Number(id);
  if (!Number.isFinite(userId)) {
    return NextResponse.json({ message: "Invalid member id." }, { status: 400 });
  }

  const { error } = await supabase.from("UserBlocks").delete().eq("blockerId", payload.id).eq("blockedId", userId);
  if (error) {
    console.error("DELETE /api/user/blocks/[id] failed:", error);
    return NextResponse.json({ message: "Failed to unblock member." }, { status: 500 });
  }
  return NextResponse.json({ blocked: false });
}
