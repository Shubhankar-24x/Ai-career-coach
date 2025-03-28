"use server";

import { db } from "@/lib/prisma";
import { auth } from "@clerk/nextjs/server";
import { revalidatePath } from "next/cache";
import { generateAIInsights } from "./dashboard";

// ✅ Ensure user exists or create them if missing
async function ensureUserExists(userId) {
  let user = await db.user.findUnique({
    where: { clerkUserId: userId },
  });

  if (!user) {
    console.warn(`⚠️ User with Clerk ID ${userId} not found. Creating new user...`);

    const clerkUser = await fetch(`https://api.clerk.dev/v1/users/${userId}`, {
      headers: { Authorization: `Bearer ${process.env.CLERK_SECRET_KEY}` },
    }).then((res) => res.json());

    if (!clerkUser || clerkUser.error) {
      throw new Error("❌ Failed to fetch Clerk user details");
    }

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
}

// ✅ Update user profile without transactions
export async function updateUser(data) {
  const { userId } = await auth();
  if (!userId) throw new Error("Unauthorized");

  try {
    // ✅ Ensure the user exists first
    const user = await ensureUserExists(userId);

    // ✅ Check if industry insight exists
    let industryInsight = await db.industryInsight.findUnique({
      where: { industry: data.industry },
    });

    // ✅ If industry doesn't exist, generate insights and create it
    if (!industryInsight) {
      const insights = await generateAIInsights(data.industry);

      industryInsight = await db.industryInsight.create({
        data: {
          industry: data.industry,
          ...insights,
          demandLevel: insights.demandLevel.toUpperCase(),
          nextUpdate: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
        },
      });
    }

    // ✅ Update the user profile separately (NOT inside a transaction)
    const updatedUser = await db.user.update({
      where: { id: user.id },
      data: {
        industry: data.industry,
        experience: data.experience,
        bio: data.bio,
        skills: data.skills,
      },
    });

    revalidatePath("/");
    return updatedUser;
  } catch (error) {
    console.error("❌ Error updating user and industry:", error.message);
    throw new Error("Failed to update profile");
  }
}

// ✅ Check user onboarding status
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
