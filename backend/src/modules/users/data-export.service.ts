import { prisma } from "../../lib/prisma.js";

/** Build a user-owned export without exposing credentials, session tokens, or document URLs. */
export async function createUserDataExport(userId: string) {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: {
      id: true,
      role: true,
      name: true,
      email: true,
      phone: true,
      avatarUrl: true,
      walletBalance: true,
      emailVerifiedAt: true,
      phoneVerifiedAt: true,
      marketingNotificationsEnabled: true,
      referralCode: true,
      referralRewardsIssued: true,
      createdAt: true,
      city: { select: { name: true } },
      addresses: {
        select: {
          id: true,
          label: true,
          line1: true,
          line2: true,
          landmark: true,
          city: { select: { name: true } },
          pincode: true,
          latitude: true,
          longitude: true,
          createdAt: true
        },
        orderBy: { createdAt: "asc" }
      },
      savedAddresses: {
        select: {
          label: true,
          addressLine1: true,
          addressLine2: true,
          landmark: true,
          city: true,
          pincode: true,
          lat: true,
          lng: true,
          isDefault: true,
          createdAt: true
        },
        orderBy: { createdAt: "asc" }
      },
      bookings: {
        select: {
          id: true,
          code: true,
          status: true,
          scheduledAt: true,
          totalAmount: true,
          createdAt: true,
          address: {
            select: {
              label: true,
              line1: true,
              line2: true,
              city: { select: { name: true } },
              pincode: true
            }
          },
          services: {
            select: {
              quantity: true,
              unitPrice: true,
              service: { select: { name: true } },
              serviceSubcategory: { select: { name: true } }
            }
          },
          payments: {
            select: { amount: true, status: true, provider: true, createdAt: true },
            orderBy: { createdAt: "asc" }
          },
          worker: { select: { fullName: true } }
        },
        orderBy: { createdAt: "asc" }
      },
      reviewsWritten: {
        select: { rating: true, comment: true, createdAt: true, workerResponse: true, workerResponseAt: true },
        orderBy: { createdAt: "asc" }
      },
      walletTransactions: {
        select: { type: true, amount: true, referenceType: true, referenceId: true, balanceAfter: true, createdAt: true },
        orderBy: { createdAt: "asc" }
      },
      supportTickets: {
        select: {
          subject: true,
          message: true,
          status: true,
          createdAt: true,
          updatedAt: true,
          replies: {
            where: { isInternal: false },
            select: { message: true, createdAt: true, isInternal: true },
            orderBy: { createdAt: "asc" }
          }
        },
        orderBy: { createdAt: "asc" }
      },
      workerProfile: {
        select: {
          fullName: true,
          gender: true,
          dateOfBirth: true,
          addressLine1: true,
          alternatePhone: true,
          city: true,
          pincode: true,
          serviceAreas: true,
          workType: true,
          acceptsUrgentJobs: true,
          aadhaarNumber: true,
          bankAccountNumber: true,
          bankIfsc: true,
          upiId: true,
          toolsOwned: true,
          emergencyContactName: true,
          emergencyContactPhone: true,
          onboardingStatus: true,
          verificationStatus: true,
          createdAt: true,
          skills: {
            select: {
              yearsExperience: true,
              isPrimary: true,
              category: { select: { name: true } }
            }
          },
          reviews: {
            where: { moderationStatus: "published" },
            select: { rating: true, comment: true, workerResponse: true, createdAt: true },
            orderBy: { createdAt: "asc" }
          }
        }
      }
    }
  });

  if (!user) return null;
  return {
    exportFormat: "veedufix-account-data",
    version: 1,
    exportedAt: new Date().toISOString(),
    user
  };
}
