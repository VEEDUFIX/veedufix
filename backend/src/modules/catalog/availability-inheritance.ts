import { Prisma } from "@prisma/client";

type AreaAssignment = { serviceAreaId: string };

export type AvailabilityNode = {
  availabilityMode: string;
  serviceAreaAssignments: AreaAssignment[];
  parent?: AvailabilityNode | null;
};

function customAreaScope(relation: "serviceAreaAssignments" | "serviceAreaAssignments", areaIds: string[]) {
  return {
    [relation]: {
      some: {
        serviceAreaId: { in: areaIds },
        serviceArea: { isActive: true, city: { isActive: true } }
      }
    }
  };
}

/** SQL filter matching the deepest explicit service availability configuration. */
export function serviceAvailabilityWhere(areaIds: string[]): Prisma.ServiceWhereInput {
  const serviceCustom = customAreaScope("serviceAreaAssignments", areaIds);
  const subcategoryCustom = customAreaScope("serviceAreaAssignments", areaIds);
  const categoryCustom = customAreaScope("serviceAreaAssignments", areaIds);
  return {
    OR: [
      { availabilityMode: "CUSTOM", ...serviceCustom },
      {
        availabilityMode: "INHERITED",
        subcategory: {
          is: { availabilityMode: "CUSTOM", ...subcategoryCustom }
        }
      },
      {
        availabilityMode: "INHERITED",
        subcategory: {
          is: {
            availabilityMode: "INHERITED",
            category: { is: { availabilityMode: "CUSTOM", ...categoryCustom } }
          }
        }
      },
      {
        availabilityMode: "INHERITED",
        subcategory: {
          is: {
            availabilityMode: "INHERITED",
            category: { is: { availabilityMode: "INHERITED" } }
          }
        }
      }
    ]
  };
}

/** Variant availability inherits from its service, then the parent catalog chain. */
export function variantAvailabilityWhere(areaIds: string[]) {
  const variantCustom = customAreaScope("serviceAreaAssignments", areaIds);
  const serviceCustom = customAreaScope("serviceAreaAssignments", areaIds);
  const subcategoryCustom = customAreaScope("serviceAreaAssignments", areaIds);
  const categoryCustom = customAreaScope("serviceAreaAssignments", areaIds);
  return {
    OR: [
      { availabilityMode: "CUSTOM", ...variantCustom },
      {
        availabilityMode: "INHERITED",
        service: { is: { availabilityMode: "CUSTOM", ...serviceCustom } }
      },
      {
        availabilityMode: "INHERITED",
        service: {
          is: {
            availabilityMode: "INHERITED",
            subcategory: { is: { availabilityMode: "CUSTOM", ...subcategoryCustom } }
          }
        }
      },
      {
        availabilityMode: "INHERITED",
        service: {
          is: {
            availabilityMode: "INHERITED",
            subcategory: {
              is: {
                availabilityMode: "INHERITED",
                category: { is: { availabilityMode: "CUSTOM", ...categoryCustom } }
              }
            }
          }
        }
      },
      {
        availabilityMode: "INHERITED",
        service: {
          is: {
            availabilityMode: "INHERITED",
            subcategory: {
              is: {
                availabilityMode: "INHERITED",
                category: { is: { availabilityMode: "INHERITED" } }
              }
            }
          }
        }
      }
    ]
  };
}

/** Returns null for unrestricted inheritance, otherwise the explicitly allowed areas. */
export function resolveAvailabilityAreaIds(node: AvailabilityNode): string[] | null {
  if (node.availabilityMode === "CUSTOM") {
    return node.serviceAreaAssignments.map((assignment) => assignment.serviceAreaId);
  }
  return node.parent ? resolveAvailabilityAreaIds(node.parent) : null;
}

export function isAvailableInAreas(node: AvailabilityNode, areaIds: string[]): boolean {
  const configured = resolveAvailabilityAreaIds(node);
  return configured === null || configured.some((id) => areaIds.includes(id));
}
