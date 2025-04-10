// app/(main)/resume/page.jsx

import dynamic from "next/dynamic";
import { getResume } from "@/actions/resume";

// Load ResumeBuilder on the client side only
const ResumeBuilder = dynamic(() => import("./_components/resume-builder"), {
  ssr: false,
});

export default async function ResumePage() {
  const resume = await getResume();

  return (
    <div className="container mx-auto py-6">
      <ResumeBuilder initialContent={resume?.content} />
    </div>
  );
}
