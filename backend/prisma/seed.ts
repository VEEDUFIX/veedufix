import { prisma } from "../src/lib/prisma.js";
import { catalogService } from "../src/modules/catalog/catalog.service.js";
import bcrypt from "bcryptjs";

type BlueprintCategory = {
  name: string;
  slug: string;
  subcategories: string[];
  skills: string[];
  tools: string[];
  documents: string[];
  featured?: boolean;
  popular?: boolean;
};

const serviceSuffixes = ["Inspection", "Installation", "Repair", "Replacement", "Maintenance"] as const;

const blueprint: BlueprintCategory[] = [
  {
    name: "Home Repair",
    slug: "home-repair",
    subcategories: ["Switches & Sockets", "Lighting & Fixtures", "Safety & Wiring"],
    skills: ["Fault Diagnosis", "Home Repair Estimation"],
    tools: ["Screwdriver Set", "Multimeter"],
    documents: ["Site Access Consent"],
    featured: true,
    popular: true
  },
  {
    name: "Cleaning",
    slug: "cleaning",
    subcategories: ["Deep Cleaning", "Kitchen Cleaning", "Bathroom Cleaning"],
    skills: ["Surface Cleaning", "Disinfection"],
    tools: ["Vacuum Cleaner", "Microfiber Kit"],
    documents: ["Cleaning Scope Approval"],
    featured: true,
    popular: true
  },
  {
    name: "Appliance Repair",
    slug: "appliance-repair",
    subcategories: ["AC Units", "Washing Machines", "Refrigerators"],
    skills: ["Diagnostics", "Spare Part Fitting"],
    tools: ["Multimeter", "Spare Parts Kit"],
    documents: ["Warranty Check"],
    popular: true
  },
  {
    name: "Painting",
    slug: "painting",
    subcategories: ["Interior Painting", "Exterior Painting", "Texture & Decor"],
    skills: ["Surface Preparation", "Finish Coating"],
    tools: ["Paint Roller Set", "Masking Kit"],
    documents: ["Color Selection Approval"],
    featured: true
  },
  {
    name: "Electrical",
    slug: "electrical",
    subcategories: ["Fan & Light", "MCB & DB", "Door Bell & CCTV"],
    skills: ["Electrical Safety", "Circuit Testing"],
    tools: ["Tester Pen", "Wire Cutter"],
    documents: ["Electrical Safety Acknowledgement"],
    popular: true
  },
  {
    name: "Plumbing",
    slug: "plumbing",
    subcategories: ["Tap & Faucet", "Leakage & Pipes", "Tank & Pump"],
    skills: ["Leak Detection", "Pipe Fitting"],
    tools: ["Pipe Wrench", "Plumbing Seal Kit"],
    documents: ["Water Access Consent"],
    popular: true
  },
  {
    name: "Carpentry",
    slug: "carpentry",
    subcategories: ["Furniture Repair", "Door & Window", "Modular Furniture"],
    skills: ["Wood Joinery", "Carpentry Measurement"],
    tools: ["Hand Saw", "Drill Machine"],
    documents: ["Work Area Clearance"]
  },
  {
    name: "Home Improvement",
    slug: "home-improvement",
    subcategories: ["False Ceiling", "Wallpaper & Panels", "Flooring & Tiling"],
    skills: ["Interior Finishing", "Measurement Planning"],
    tools: ["Laser Level", "Tile Cutter"],
    documents: ["Design Sign-off"]
  },
  {
    name: "Electronics Repair",
    slug: "electronics-repair",
    subcategories: ["TVs & Audio", "Laptops & PCs", "Smart Devices"],
    skills: ["Board Diagnostics", "Component Replacement"],
    tools: ["Soldering Kit", "Static Wrist Strap"],
    documents: ["Device Access Approval"]
  },
  {
    name: "Automobile",
    slug: "automobile",
    subcategories: ["Two Wheeler", "Four Wheeler", "Battery & Accessories"],
    skills: ["Vehicle Diagnostics", "Battery Testing"],
    tools: ["Tyre Pressure Gauge", "OBD Scanner"],
    documents: ["Vehicle Access Approval"]
  },
  {
    name: "Beauty & Wellness",
    slug: "beauty-wellness",
    subcategories: ["Hair Care", "Skincare", "Grooming"],
    skills: ["Personal Care", "Sanitation"],
    tools: ["Sterilizer Kit", "Salon Kit"],
    documents: ["Service Consent"]
  },
  {
    name: "Laundry",
    slug: "laundry",
    subcategories: ["Wash & Fold", "Dry Cleaning", "Steam Ironing"],
    skills: ["Fabric Care", "Stain Treatment"],
    tools: ["Steam Iron", "Laundry Bag Kit"],
    documents: ["Pickup Consent"]
  },
  {
    name: "Moving",
    slug: "moving",
    subcategories: ["Packing", "Truck Loading", "Unpacking"],
    skills: ["Packing Strategy", "Load Management"],
    tools: ["Moving Blankets", "Strap Kit"],
    documents: ["Move Inventory List"]
  },
  {
    name: "Pest Control",
    slug: "pest-control",
    subcategories: ["Termites", "Cockroaches & Ants", "Mosquitoes"],
    skills: ["Chemical Safety", "Infestation Treatment"],
    tools: ["Sprayer Kit", "Protective Gear"],
    documents: ["Safety Declaration"],
    popular: true
  },
  {
    name: "Home Care",
    slug: "home-care",
    subcategories: ["Elder Care", "Patient Care", "Child Care"],
    skills: ["Companionship", "Care Support"],
    tools: ["Care Log Kit", "Thermometer"],
    documents: ["Care Consent"]
  }
];

function slugify(value: string): string {
  return value
    .normalize("NFKD")
    .replace(/[^\w\s-]/g, "")
    .trim()
    .toLowerCase()
    .replace(/[\s_-]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

async function seedCities() {
  const cities = [
    { name: "Chennai", state: "Tamil Nadu", slug: "chennai" },
    { name: "Bengaluru", state: "Karnataka", slug: "bengaluru" },
    { name: "Hyderabad", state: "Telangana", slug: "hyderabad" }
  ];

  for (const city of cities) {
    await prisma.city.upsert({
      where: { slug: city.slug },
      update: {
        name: city.name,
        state: city.state,
        country: "India",
        isActive: true
      },
      create: {
        name: city.name,
        state: city.state,
        country: "India",
        slug: city.slug
      }
    });
  }
}

async function seedCatalog() {
  const createdServices: Array<{ id: string; slug: string; name: string }> = [];

  for (let categoryIndex = 0; categoryIndex < blueprint.length; categoryIndex += 1) {
    const category = blueprint[categoryIndex];
    const createdCategory = await catalogService.createCategory({
      name: category.name,
      slug: category.slug,
      description: `${category.name} services for VeeduFix customers.`,
      seoTitle: `${category.name} Services`,
      seoDescription: `Book trusted ${category.name.toLowerCase()} services on VeeduFix.`,
      sortOrder: categoryIndex,
      featured: category.featured,
      popular: category.popular
    });

    for (let subIndex = 0; subIndex < category.subcategories.length; subIndex += 1) {
      const subcategoryName = category.subcategories[subIndex];
      const subcategorySlug = slugify(`${category.slug}-${subcategoryName}`);
      const createdSubcategory = await catalogService.createSubcategory({
        categoryId: createdCategory.id,
        name: subcategoryName,
        slug: subcategorySlug,
        description: `${subcategoryName} under ${category.name}.`,
        basePrice: 299 + categoryIndex * 40 + subIndex * 25,
        sortOrder: subIndex,
        rating: 4.5 + (subIndex % 3) * 0.1,
        reviewCount: 80 + categoryIndex * 11 + subIndex * 7
      });

      for (let serviceIndex = 0; serviceIndex < serviceSuffixes.length; serviceIndex += 1) {
        const suffix = serviceSuffixes[serviceIndex];
        const serviceName = `${subcategoryName} ${suffix}`;
        const serviceSlug = slugify(`${category.slug}-${subcategoryName}-${suffix}`);
        const service = await catalogService.createService({
          categoryId: createdCategory.id,
          subcategoryId: createdSubcategory.id,
          name: serviceName,
          slug: serviceSlug,
          code: `VEEDU-${categoryIndex + 1}${subIndex + 1}${serviceIndex + 1}`.padEnd(12, "0"),
          description: `Professional ${serviceName.toLowerCase()} delivered by verified VeeduFix experts.`,
          shortDescription: `Reliable ${serviceName.toLowerCase()}.`,
          startingPrice: 299 + categoryIndex * 45 + subIndex * 35 + serviceIndex * 40,
          estimatedDurationMins: 30 + serviceIndex * 20,
          warrantyDays: 7 + serviceIndex * 7,
          gstApplicable: true,
          emergencyAvailable: serviceIndex % 2 === 0,
          homeVisit: true,
          featured: serviceIndex === 0,
          popular: serviceIndex <= 2,
          rating: 4.4 + serviceIndex * 0.1,
          reviewCount: 42 + categoryIndex * 9 + serviceIndex * 13,
          iconUrl: undefined,
          sortOrder: serviceIndex,
          requiredSkills: category.skills.map((skill, skillIndex) => ({
            name: skill,
            slug: `${slugify(skill)}-${slugify(category.slug)}-${slugify(subcategoryName)}`,
            sortOrder: skillIndex
          })),
          requiredTools: category.tools.map((tool, toolIndex) => ({
            name: tool,
            slug: `${slugify(tool)}-${slugify(category.slug)}-${slugify(subcategoryName)}`,
            sortOrder: toolIndex
          })),
          requiredDocuments: category.documents.map((document, documentIndex) => ({
            name: document,
            slug: `${slugify(document)}-${slugify(category.slug)}-${slugify(subcategoryName)}`,
            sortOrder: documentIndex
          })),
          images: [
            {
              url: `https://images.unsplash.com/photo-1523413651479-597eb2da0ad6?auto=format&fit=crop&w=1200&q=80`,
              altText: serviceName,
              sortOrder: 0,
              isPrimary: true
            }
          ]
        });

        createdServices.push({ id: service.id, slug: service.slug, name: service.name });
      }
    }
  }

  const chennai = await prisma.city.findUnique({ where: { slug: "chennai" } });
  const bengaluru = await prisma.city.findUnique({ where: { slug: "bengaluru" } });

  const featuredService = createdServices.find((item) => item.slug.includes("home-repair-switches-sockets-inspection"));
  const cleaningService = createdServices.find((item) => item.slug.includes("cleaning-deep-cleaning-installation"));
  const plumbingService = createdServices.find((item) => item.slug.includes("plumbing-tap-faucet-repair"));

  if (featuredService && chennai) {
    await catalogService.upsertPriceRule(featuredService.id, {
      cityId: chennai.id,
      type: "CITY",
      title: "Chennai city price",
      price: 349,
      currency: "INR",
      isActive: true,
      priority: 100
    });
  }

  if (cleaningService && bengaluru) {
    await catalogService.upsertPriceRule(cleaningService.id, {
      cityId: bengaluru.id,
      type: "PROMOTIONAL",
      title: "Launch offer",
      price: 499,
      currency: "INR",
      isActive: true,
      priority: 90
    });
  }

  if (plumbingService && chennai) {
    await catalogService.upsertPriceRule(plumbingService.id, {
      cityId: chennai.id,
      type: "SEASONAL",
      title: "Monsoon plumbing offer",
      price: 299,
      currency: "INR",
      isActive: true,
      priority: 80
    });
  }

  return createdServices.length;
}

async function seedApprovedWorkers() {
  const adminPasswordHash = await bcrypt.hash("Admin@12345", 10);
  const workerPasswordHash = await bcrypt.hash("Worker@12345", 10);

  const admin = await prisma.user.upsert({
    where: { email: "admin@veedufix.local" },
    update: {
      name: "VeeduFix Admin",
      role: "ADMIN",
      passwordHash: adminPasswordHash,
      isActive: true
    },
    create: {
      name: "VeeduFix Admin",
      email: "admin@veedufix.local",
      role: "ADMIN",
      passwordHash: adminPasswordHash,
      isActive: true
    }
  });

  const [chennai, bengaluru, hyderabad] = await Promise.all([
    prisma.city.findUnique({ where: { slug: "chennai" } }),
    prisma.city.findUnique({ where: { slug: "bengaluru" } }),
    prisma.city.findUnique({ where: { slug: "hyderabad" } })
  ]);

  const categories = await prisma.serviceCategory.findMany({
    where: {
      slug: {
        in: ["home-repair", "cleaning", "appliance-repair", "plumbing", "electrical"]
      }
    },
    orderBy: { slug: "asc" }
  });

  const categoryBySlug = new Map(categories.map((category) => [category.slug, category]));
  const cityCentroids = {
    Chennai: { latitude: 13.0827, longitude: 80.2707 },
    Bengaluru: { latitude: 12.9716, longitude: 77.5946 },
    Hyderabad: { latitude: 17.385, longitude: 78.4867 }
  } as const;

  const workerSeeds = [
    {
      name: "Arun Kumar",
      email: "arun.worker@veedufix.local",
      cityId: chennai?.id,
      cityName: "Chennai",
      displayName: "Arun Kumar",
      profileSlug: "home-repair",
      skills: [
        { categorySlug: "home-repair", yearsExperience: 6, isPrimary: true },
        { categorySlug: "electrical", yearsExperience: 3, isPrimary: false }
      ]
    },
    {
      name: "Priya Nair",
      email: "priya.worker@veedufix.local",
      cityId: bengaluru?.id,
      cityName: "Bengaluru",
      displayName: "Priya Nair",
      profileSlug: "cleaning",
      skills: [
        { categorySlug: "cleaning", yearsExperience: 5, isPrimary: true }
      ]
    },
    {
      name: "Suresh Reddy",
      email: "suresh.worker@veedufix.local",
      cityId: hyderabad?.id,
      cityName: "Hyderabad",
      displayName: "Suresh Reddy",
      profileSlug: "appliance-repair",
      skills: [
        { categorySlug: "appliance-repair", yearsExperience: 8, isPrimary: true },
        { categorySlug: "electrical", yearsExperience: 4, isPrimary: false }
      ]
    },
    {
      name: "Meera Joseph",
      email: "meera.worker@veedufix.local",
      cityId: chennai?.id,
      cityName: "Chennai",
      displayName: "Meera Joseph",
      profileSlug: "plumbing",
      skills: [
        { categorySlug: "plumbing", yearsExperience: 7, isPrimary: true }
      ]
    }
  ];

  for (const workerSeed of workerSeeds) {
    if (!workerSeed.cityId) {
      continue;
    }

    const user = await prisma.user.upsert({
      where: { email: workerSeed.email },
      update: {
        name: workerSeed.name,
        role: "WORKER",
        passwordHash: workerPasswordHash,
        cityId: workerSeed.cityId,
        isActive: true
      },
      create: {
        name: workerSeed.name,
        email: workerSeed.email,
        role: "WORKER",
        passwordHash: workerPasswordHash,
        cityId: workerSeed.cityId,
        isActive: true
      }
    });

    const profile = await prisma.workerProfile.upsert({
      where: { userId: user.id },
      update: {
        onboardingStatus: "approved",
        fullName: workerSeed.name,
        addressLine1: "12 Sample Street",
        city: workerSeed.cityName,
        pincode: "600001",
        aadhaarNumber: "XXXX-XXXX-1234",
        aadhaarDocUrl: "https://res.cloudinary.com/demo/image/upload/sample-aadhaar.jpg",
        bankAccountNumber: "123456789012",
        bankIfsc: "SBIN0000001",
        upiId: `${workerSeed.email.split("@")[0]}@upi`,
        reviewedBy: admin.id,
        reviewedAt: new Date(),
        submittedAt: new Date(),
        verificationStatus: "VERIFIED",
        displayName: workerSeed.displayName,
        cityId: workerSeed.cityId,
        latitude: cityCentroids[workerSeed.cityName as keyof typeof cityCentroids].latitude,
        longitude: cityCentroids[workerSeed.cityName as keyof typeof cityCentroids].longitude
      },
      create: {
        userId: user.id,
        onboardingStatus: "approved",
        fullName: workerSeed.name,
        addressLine1: "12 Sample Street",
        city: workerSeed.cityName,
        pincode: "600001",
        aadhaarNumber: "XXXX-XXXX-1234",
        aadhaarDocUrl: "https://res.cloudinary.com/demo/image/upload/sample-aadhaar.jpg",
        bankAccountNumber: "123456789012",
        bankIfsc: "SBIN0000001",
        upiId: `${workerSeed.email.split("@")[0]}@upi`,
        reviewedBy: admin.id,
        reviewedAt: new Date(),
        submittedAt: new Date(),
        verificationStatus: "VERIFIED",
        displayName: workerSeed.displayName,
        cityId: workerSeed.cityId,
        latitude: cityCentroids[workerSeed.cityName as keyof typeof cityCentroids].latitude,
        longitude: cityCentroids[workerSeed.cityName as keyof typeof cityCentroids].longitude
      }
    });

    await prisma.workerSkill.deleteMany({
      where: { workerProfileId: profile.id }
    });

    const skills = workerSeed.skills
      .map((skill) => {
        const category = categoryBySlug.get(skill.categorySlug);
        if (!category) {
          return null;
        }

        return {
          workerProfileId: profile.id,
          categoryId: category.id,
          yearsExperience: skill.yearsExperience,
          isPrimary: skill.isPrimary,
          verifiedByAdmin: true,
          certificationDocUrl: `https://res.cloudinary.com/demo/image/upload/${skill.categorySlug}.jpg`
        };
      })
      .filter((value): value is NonNullable<typeof value> => value !== null);

    if (skills.length > 0) {
      await prisma.workerSkill.createMany({
        data: skills
      });
    }
  }
}

async function main() {
  await seedCities();
  const serviceCount = await seedCatalog();
  await seedApprovedWorkers();
  console.log(`Seed complete: ${blueprint.length} categories, ${serviceCount} services, approved workers seeded`);
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
