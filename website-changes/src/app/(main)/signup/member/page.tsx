"use client";

import React, { useRef, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useAuth } from "@/context/AuthContext";
import { Turnstile, type TurnstileInstance } from "@marsidev/react-turnstile";

const EyeIcon = ({ open }: { open: boolean }) =>
  open ? (
    <svg xmlns="http://www.w3.org/2000/svg" className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.8}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M3.98 8.223A10.477 10.477 0 0 0 1.934 12c1.292 4.338 5.31 7.5 10.066 7.5.993 0 1.953-.138 2.863-.395M6.228 6.228A10.451 10.451 0 0 1 12 4.5c4.756 0 8.773 3.162 10.065 7.498a10.522 10.522 0 0 1-4.293 5.774M6.228 6.228 3 3m3.228 3.228 3.65 3.65m7.894 7.894L21 21m-3.228-3.228-3.65-3.65m0 0a3 3 0 1 0-4.243-4.243m4.242 4.242L9.88 9.88" />
    </svg>
  ) : (
    <svg xmlns="http://www.w3.org/2000/svg" className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.8}>
      <path strokeLinecap="round" strokeLinejoin="round" d="M2.036 12.322a1.012 1.012 0 0 1 0-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178Z" />
      <path strokeLinecap="round" strokeLinejoin="round" d="M15 12a3 3 0 1 1-6 0 3 3 0 0 1 6 0Z" />
    </svg>
  );


const SITE_KEY = process.env.NEXT_PUBLIC_TURNSTILE_SITE_KEY ?? "";

const SignupMember = () => {
  const { signup } = useAuth();
  const router = useRouter();
  const turnstileRef = useRef<TurnstileInstance>(null);

  const [showPassword, setShowPassword] = useState(false);
  const [formData, setFormData] = useState({ email: "", password: "", firstName: "", lastName: "" });
  const [turnstileToken, setTurnstileToken] = useState<string | null>(null);
  const [acceptedTerms, setAcceptedTerms] = useState(false);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) =>
    setFormData({ ...formData, [e.target.name]: e.target.value });

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");

    if (!turnstileToken) {
      setError("Please complete the security check.");
      return;
    }
    if (!acceptedTerms) {
      setError("Please agree to the Terms of Use.");
      return;
    }

    setLoading(true);
    try {
      await signup({
        email: formData.email,
        password: formData.password,
        firstName: formData.firstName,
        lastName: formData.lastName,
        turnstileToken,
        acceptedTerms,
      });
      router.push("/dashboard/feed");
    } catch (err: any) {
      setError(err?.message || "Registration failed");
      // Reset widget so user can retry
      turnstileRef.current?.reset();
      setTurnstileToken(null);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-[80vh] flex items-center justify-center px-4 py-16">
      <div className="w-full max-w-md bg-white shadow-xl rounded-2xl p-10">
        <div className="mb-8 text-center">
          <img src="/header-logo.svg" alt="AMSA" className="h-12 mx-auto mb-4" />
          <h2 className="text-3xl font-bold text-[#001049]">Create an account</h2>
          <p className="text-gray-400 text-sm mt-1">Join the AMSA community</p>
        </div>

        <form onSubmit={handleSubmit} className="space-y-5">
          {error && (
            <div className="bg-red-50 border border-red-200 text-red-700 text-sm rounded-lg px-4 py-3">
              {error}
            </div>
          )}

          <div className="grid grid-cols-2 gap-3">
            <div className="space-y-1">
              <label className="block text-sm font-medium text-gray-700">First Name</label>
              <input name="firstName" placeholder="First" onChange={handleChange} className="input w-full" required />
            </div>
            <div className="space-y-1">
              <label className="block text-sm font-medium text-gray-700">Last Name</label>
              <input name="lastName" placeholder="Last" onChange={handleChange} className="input w-full" required />
            </div>
          </div>

        <div className="space-y-1">
            <label className="block text-sm font-medium text-gray-700">Email</label>
            <input
              type="email"
              name="email"
              placeholder="you@example.com"
              onChange={handleChange}
              className="input w-full"
              required
            />
          </div>

          <div className="space-y-1">
            <label className="block text-sm font-medium text-gray-700">Password</label>
            <div className="relative">
              <input
                type={showPassword ? "text" : "password"}
                name="password"
                placeholder="password"
                onChange={handleChange}
                className="input w-full pr-11"
                required
              />
              <button
                type="button"
                onClick={() => setShowPassword(!showPassword)}
                className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600 transition"
                aria-label={showPassword ? "Hide password" : "Show password"}
              >
                <EyeIcon open={showPassword} />
              </button>
            </div>
          </div>

          <label className="flex items-start gap-3 text-sm text-gray-600">
            <input
              type="checkbox"
              checked={acceptedTerms}
              onChange={(e) => setAcceptedTerms(e.target.checked)}
              className="mt-0.5 h-4 w-4 shrink-0 accent-[#001049]"
              required
            />
            <span>
              I agree to the{" "}
              <Link href="/terms" target="_blank" className="text-[#001049] font-medium hover:underline">
                Terms of Use
              </Link>{" "}
              and{" "}
              <Link href="/privacy" target="_blank" className="text-[#001049] font-medium hover:underline">
                Privacy Policy
              </Link>
              . There is no tolerance for objectionable content or abusive members.
            </span>
          </label>

          <Turnstile
            ref={turnstileRef}
            siteKey={SITE_KEY}
            onSuccess={setTurnstileToken}
            onExpire={() => setTurnstileToken(null)}
            onError={() => {
              setTurnstileToken(null);
              setError("Security check failed. Please refresh and try again.");
            }}
            options={{ theme: "light" }}
          />

          <button
            type="submit"
            disabled={loading || !turnstileToken || !acceptedTerms}
            className="w-full bg-[#001049] text-white py-3 rounded-xl font-medium hover:bg-[#001A78] transition disabled:opacity-50 mt-2"
          >
            {loading ? "Creating account…" : "Create Account"}
          </button>
        <p className="text-center text-sm text-gray-400 pt-2">
            Already have an account?{" "}
            <Link href="/login" className="text-[#001049] font-medium hover:underline">
              Sign in
            </Link>
          </p>
        </form>
      </div>
    </div>
  );
};

export default SignupMember;
