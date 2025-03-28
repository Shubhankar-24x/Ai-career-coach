import { getIndustryInsights } from "@/actions/dashboard";
import DashboardView from "./_components/dashboard-view";
import { getUserOnboardingStatus } from "@/actions/user";
import { redirect } from "next/navigation";

export default async function DashboardPage() {
  let isOnboarded = false; // Default to false in case of an error

  try {
    const status = await getUserOnboardingStatus();
    isOnboarded = status?.isOnboarded || false;
  } catch (error) {
    console.error("Error fetching onboarding status:", error.message);
    // Optional: Handle errors differently (e.g., redirect to login)
  }

  // Redirect if the user is not onboarded
  if (!isOnboarded) {
    redirect("/onboarding");
  }

  const insights = await getIndustryInsights();

  return (
    <div className="container mx-auto">
      <DashboardView insights={insights} />
    </div>
  );
}
