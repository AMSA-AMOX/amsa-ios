import Link from "next/link";
import { LegalList, LegalPage, LegalSection } from "@/components/legal/LegalPage";
import { SUPPORT_EMAIL } from "@/lib/legal";

export const metadata = {
  title: "Terms of Use | AMSA",
  description: "The rules for using the AMSA website and app.",
};

export default function TermsPage() {
  return (
    <LegalPage title="Terms of Use">
      <LegalSection title="1. Agreement">
        <p>
          These Terms of Use govern your use of the Association of Mongolian Students in America (&quot;AMSA&quot;,
          &quot;we&quot;) website at amsa.mn and the AMSA mobile app (together, the &quot;Service&quot;). By creating an
          account or using the Service you agree to these Terms and to our{" "}
          <Link href="/privacy" className="text-[#001049] font-medium underline">Privacy Policy</Link>. If you do not
          agree, do not use the Service.
        </p>
        <p>
          You must be at least 13 years old to use the Service. If you are under 18, you confirm that a parent or
          guardian has agreed to these Terms for you.
        </p>
      </LegalSection>

      <LegalSection title="2. Your account">
        <p>
          Give accurate information when you sign up and keep your password private. You are responsible for
          everything that happens under your account. Tell us at {SUPPORT_EMAIL} if you think someone else is using
          it.
        </p>
      </LegalSection>

      <LegalSection title="3. Community rules — zero tolerance">
        <p>
          AMSA is a community for students. <strong>There is no tolerance for objectionable content or abusive
          users.</strong> You may not post, upload, send or link to anything that:
        </p>
        <LegalList
          items={[
            "harasses, bullies, threatens, intimidates or stalks anyone;",
            "is hateful or discriminatory, including on the basis of race, ethnicity, nationality, religion, gender, sexual orientation, disability or age;",
            "is sexually explicit or pornographic, or sexualizes minors in any way;",
            "promotes or depicts violence, self-harm, or illegal activity;",
            "is spam, a scam, or misleading advertising;",
            "impersonates another person or misrepresents your affiliation with a school or organization;",
            "shares someone else's private information without their permission;",
            "infringes anyone's copyright, trademark or other rights; or",
            "breaks any law.",
          ]}
        />
      </LegalSection>

      <LegalSection title="4. Reporting, blocking and moderation">
        <LegalList
          items={[
            <>
              <strong>Report</strong>: every post, thread, comment, review, direct question and member profile has a
              Report option. Reports go to AMSA moderators.
            </>,
            <>
              <strong>Block</strong>: you can block any member. You will no longer see each other&apos;s content, and
              they cannot follow you or send you questions. You can unblock them in Settings.
            </>,
            <>
              Some posts and threads are reviewed by moderators before they are published.
            </>,
            <>
              We review reports within 24 hours. We remove content that breaks these Terms and may suspend or
              permanently remove the accounts of members who post it.
            </>,
          ]}
        />
      </LegalSection>

      <LegalSection title="5. Your content">
        <p>
          You keep ownership of what you post. By posting it, you give AMSA a non-exclusive, worldwide, royalty-free
          license to host, display and distribute it within the Service so that other members can see it. This
          license ends when you delete the content or your account, except where others have already shared it or
          we must keep it to comply with the law.
        </p>
        <p>
          You are responsible for your content. We may remove any content, at any time, if we believe it breaks these
          Terms.
        </p>
      </LegalSection>

      <LegalSection title="6. College and place information">
        <p>
          College costs, aid, admissions and other data in the Service come from public sources such as the College
          Scorecard, the Common Data Set and IPEDS, and from members. It is for general information only and may be
          incomplete or out of date. Always confirm details with each school.
        </p>
      </LegalSection>

      <LegalSection title="7. Ending your account">
        <p>
          You can delete your account at any time in Settings. We may suspend or end your access if you break these
          Terms or put other members at risk.
        </p>
      </LegalSection>

      <LegalSection title="8. Disclaimers and liability">
        <p>
          The Service is provided &quot;as is&quot;, without warranties of any kind. To the fullest extent allowed by
          law, AMSA is not liable for indirect or consequential damages, or for content posted by members.
        </p>
      </LegalSection>

      <LegalSection title="9. Changes">
        <p>
          We may update these Terms. If the changes are significant we will tell you in the Service, and we may ask
          you to agree again before you keep using it.
        </p>
      </LegalSection>

      <LegalSection title="10. Contact">
        <p>
          Questions or concerns: <a href={`mailto:${SUPPORT_EMAIL}`} className="text-[#001049] font-medium underline">{SUPPORT_EMAIL}</a>.
        </p>
      </LegalSection>
    </LegalPage>
  );
}
