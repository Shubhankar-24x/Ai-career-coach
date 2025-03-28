import { redirect } from "next/navigation"; 
import { getUserOnboardingStatus } from "@/actions/user";
import { industries } from "@/data/industries";
import OnboardingForm from "./_components/onboarding-form";

const OnboardingPage = async () => {
  let isOnboarded = false;

  try {
    const status = await getUserOnboardingStatus();
    isOnboarded = status?.isOnboarded || false;
  } catch (error) {
    console.error("Error fetching onboarding status:", error.message);
    isOnboarded = false; // Fallback to false if there's an error
  }

  if (isOnboarded) {
    redirect("/dashboard");
  }

  return (
    <main>
      <OnboardingForm industries={industries} />
    </main>
  );
};

export default OnboardingPage;
