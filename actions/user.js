"use server";

import { db } from "@/lib/prisma";
import { auth } from "@clerk/nextjs/server";
import { revalidatePath } from "next/cache";
import { generateAIInsights } from "./dashboard";

/** ✅ Ensure user exists or create if missing */
async function ensureUserExists(userId) {
  try {
    let user = await db.user.findUnique({
      where: { clerkUserId: userId },
    });

    if (!user) {
      console.warn(`⚠️ User with Clerk ID ${userId} not found. Fetching from Clerk...`);

      // 🔍 Fetch user details from Clerk API
      const response = await fetch(`https://api.clerk.dev/v1/users/${userId}`, {
        headers: { Authorization: `Bearer ${process.env.CLERK_SECRET_KEY}` },
      });

      if (!response.ok) {
        throw new Error(`❌ Clerk API Error: ${response.status} - ${response.statusText}`);
      }

      const clerkUser = await response.json();
      console.log("✅ Clerk User Data:", clerkUser);

      // 🛑 Check if Clerk user data is valid
      if (!clerkUser || clerkUser.error) {
        throw new Error("❌ Failed to fetch valid Clerk user details");
      }

      // ✅ Create user in Prisma
      user = await db.user.create({
        data: {
          clerkUserId: userId,
          email: clerkUser.email_addresses[0]?.email_address || "unknown@example.com",
          name: clerkUser.first_name || "Unnamed User",
          imageUrl: clerkUser.profile_image_url || "",
        },
      });

      console.log("✅ New user created:", user);
    }

    return user;
  } catch (error) {
    console.error("❌ Error in ensureUserExists:", error.message);
    throw new Error("Failed to ensure user exists");
  }
}

/** ✅ Update user profile */
export async function updateUser(data) {
  const { userId } = await auth();
  if (!userId) throw new Error("Unauthorized");

  try {
    // ✅ Ensure user exists
    const user = await ensureUserExists(userId);

    // 🔍 Check if industry insight already exists
    let industryInsight = await db.industryInsight.findUnique({
      where: { industry: data.industry },
    });

    // 🛠 If not, generate AI insights and create one
    if (!industryInsight) {
      console.log(`⚡ Generating AI insights for ${data.industry}...`);
      const insights = await generateAIInsights(data.industry);

      industryInsight = await db.industryInsight.create({
        data: {
          industry: data.industry,
          ...insights,
          demandLevel: insights.demandLevel.toUpperCase(),
          nextUpdate: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000), // 7 days later
        },
      });

      console.log("✅ New industry insight created:", industryInsight);
    }

    // ✅ Update user profile
    const updatedUser = await db.user.update({
      where: { id: user.id },
      data: {
        industry: data.industry,
        experience: data.experience,
        bio: data.bio,
        skills: data.skills,
      },
    });

    // 🔄 Revalidate cache
    revalidatePath("/");
    console.log("✅ User profile updated:", updatedUser);
    return updatedUser;
  } catch (error) {
    console.error("❌ Error updating user:", error.message);
    throw new Error("Failed to update profile");
  }
}

/** ✅ Check user onboarding status */
export async function getUserOnboardingStatus() {
  const { userId } = await auth();
  if (!userId) return { isOnboarded: false };

  try {
    const user = await db.user.findUnique({
      where: { clerkUserId: userId },
      select: { industry: true },
    });

    return { isOnboarded: !!user?.industry };
  } catch (error) {
    console.error("❌ Error checking onboarding status:", error.message);
    return { isOnboarded: false };
  }
}