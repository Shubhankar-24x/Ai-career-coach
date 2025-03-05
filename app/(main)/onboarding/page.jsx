import { redirect } from "next/navigation"; // ✅ Import redirect
import { getUserOnboardingStatus } from "@/actions/user";
import { industries } from "@/data/industries";
import OnboardingForm from "./_components/onboarding-form";

const OnboardingPage = async () => {
  // Check if user is already onboarded
  const { isOnboarded } = await getUserOnboardingStatus();

  if (isOnboarded) {
    redirect("/dashboard"); // ✅ Server-side redirection
  }

  return (
    <main>
      <OnboardingForm industries={industries} />
    </main>
  );
};

export default OnboardingPage;
