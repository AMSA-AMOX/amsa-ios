import Link from "next/link";
import { LegalList, LegalPage, LegalSection } from "@/components/legal/LegalPage";
import { SUPPORT_EMAIL } from "@/lib/legal";

export const metadata = {
  title: "Privacy Policy | AMSA",
  description: "What the AMSA website and app collect, why, and your choices.",
};

export default function PrivacyPage() {
  return (
    <LegalPage title="Privacy Policy">
      <LegalSection title="1. Who we are">
        <p>
          This policy explains how the Association of Mongolian Students in America (&quot;AMSA&quot;, &quot;we&quot;)
          handles personal information in the amsa.mn website and the AMSA mobile app (the &quot;Service&quot;). It
          should be read with our <Link href="/terms" className="text-[#001049] font-medium underline">Terms of Use</Link>.
        </p>
      </LegalSection>

      <LegalSection title="2. What we collect">
        <LegalList
          items={[
            <><strong>Account</strong>: your name, email address and password (stored only as a secure hash).</>,
            <>
              <strong>Profile</strong> (all optional): photo, headline, bio, school and school email, major, degree,
              year and graduation year, city and state, phone number, personal email, social media links, education
              and work experience.
            </>,
            <>
              <strong>Membership applications</strong>: the details you submit to become a US Member, and the
              moderators&apos; decision.
            </>,
            <>
              <strong>Content and activity</strong>: posts and their images, threads, comments, reviews, direct
              questions and answers, upvotes and appreciations, follows, event reservations, saved colleges, and the
              reports and blocks you make.
            </>,
            <><strong>Support</strong>: feedback you send us.</>,
            <>
              <strong>Technical</strong>: our servers keep standard request logs (such as IP address and time), and a
              security check at signup uses your IP address to stop bots.
            </>,
          ]}
        />
        <p>
          We do not use advertising, we do not sell your information, and the app does not track you across other
          companies&apos; apps or websites.
        </p>
      </LegalSection>

      <LegalSection title="3. How we use it">
        <LegalList
          items={[
            "to run the Service: your account, your profile, and showing your content to other members;",
            "to connect members, for example by suggesting people at the same school;",
            "to review membership applications;",
            "to keep the community safe: moderating content, acting on reports and enforcing blocks;",
            "to send account emails such as welcome messages, password resets and event updates; and",
            "to answer feedback and support requests.",
          ]}
        />
      </LegalSection>

      <LegalSection title="4. Who can see it">
        <p>
          Your name, photo, school, role and the content you post are visible to other signed-in members. Some
          content, such as college and place reviews, can appear on public pages of the website. Your email address,
          phone number and personal email are not shown on your public profile. Anonymous posts and comments hide your
          name from other members but not from moderators.
        </p>
        <p>We share information with service providers only to run the Service:</p>
        <LegalList
          items={[
            "Supabase — database and file storage;",
            "Vercel — website and API hosting;",
            "Resend — email delivery;",
            "Cloudflare Turnstile — bot protection at signup; and",
            "logo.dev — school and company logos (it receives the school or company website, not your personal information).",
          ]}
        />
        <p>We may also disclose information when the law requires it.</p>
      </LegalSection>

      <LegalSection title="5. Keeping and deleting your information">
        <p>
          We keep your information while your account exists. You can delete your account at any time in Settings
          (on the website or in the app). This permanently removes your profile, posts, questions, comments, reviews,
          event reservations, reports and blocks. Some records may stay in backups for a short time before they are
          overwritten.
        </p>
      </LegalSection>

      <LegalSection title="6. Your choices">
        <LegalList
          items={[
            "edit or remove profile details at any time;",
            "delete any post or review you wrote;",
            "block members you don't want to interact with; and",
            `email us at ${SUPPORT_EMAIL} to ask for a copy of your information or to correct it.`,
          ]}
        />
      </LegalSection>

      <LegalSection title="7. Children">
        <p>
          The Service is meant for students and is not directed at children under 13. If you believe a child under
          13 has created an account, contact us and we will delete it.
        </p>
      </LegalSection>

      <LegalSection title="8. Security">
        <p>
          Passwords are hashed, connections are encrypted, and access to member data is limited to what the Service
          needs. No system is perfectly secure, so please use a strong, unique password.
        </p>
      </LegalSection>

      <LegalSection title="9. Changes and contact">
        <p>
          We will post any changes here and update the effective date. Questions:{" "}
          <a href={`mailto:${SUPPORT_EMAIL}`} className="text-[#001049] font-medium underline">{SUPPORT_EMAIL}</a>.
        </p>
      </LegalSection>
    </LegalPage>
  );
}
