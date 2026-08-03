import PDFDocument from "pdfkit";
import { PaymentStatus, Prisma } from "@prisma/client";

type BookingWithDetails = Prisma.BookingGetPayload<{
  include: {
    customer: true;
    services: {
      include: {
        service: true;
        serviceSubcategory: true;
      };
    };
    worker: {
      include: { user: true };
    };
    payments: true;
  };
}>;

export async function generateInvoicePdf(booking: BookingWithDetails): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    const doc = new PDFDocument({ margin: 50 });
    const buffers: Buffer[] = [];

    doc.on("data", (buffer: Buffer) => buffers.push(buffer));
    doc.on("end", () => resolve(Buffer.concat(buffers)));
    doc.on("error", (err: Error) => reject(err));

    const primary = "#4F46E5";
    const textDark = "#1E293B";
    const textLight = "#64748B";
    const border = "#E2E8F0";

    doc.fontSize(24).fillColor(primary).text("Veedufix", { align: "left" });
    doc.fontSize(10).fillColor(textLight).text("Premium Home Services", { align: "left" });
    doc.moveDown(1);

    doc.moveTo(50, doc.y).lineTo(550, doc.y).stroke(border);
    doc.moveDown(1);

    doc.fontSize(16).fillColor(textDark).text("INVOICE", { align: "right", continued: true }).text("");
    doc
      .fontSize(10)
      .fillColor(textLight)
      .text(`Booking Ref: #${booking.code}`, { align: "right" })
      .text(`Date: ${booking.scheduledAt.toLocaleDateString()}`, { align: "right" })
      .text(`Status: ${booking.status}`, { align: "right" });

    doc.moveUp(4);

    doc.fontSize(12).fillColor(textDark).text("Billed To:", { align: "left" });
    doc
      .fontSize(10)
      .fillColor(textLight)
      .text(booking.customer.name ?? "Customer")
      .text(booking.customer.email ?? "");
    doc.moveDown(1);

    doc.moveDown(2);
    const tableTop = doc.y;

    doc.fontSize(10).fillColor(textDark).font("Helvetica-Bold");
    doc.text("Description", 50, tableTop);
    doc.text("Amount", 400, tableTop, { width: 150, align: "right" });

    doc.moveTo(50, tableTop + 15).lineTo(550, tableTop + 15).stroke(border);

    doc.font("Helvetica").fillColor(textLight);
    let y = tableTop + 25;

    const primaryItem = booking.services[0];
    const serviceName =
      primaryItem?.service?.name ?? primaryItem?.serviceSubcategory?.name ?? "Service";
    const baseAmount =
      primaryItem?.service?.startingPrice ?? primaryItem?.serviceSubcategory?.basePrice ?? booking.totalAmount;

    doc.text(serviceName, 50, y);
    doc.text(`INR ${Number(baseAmount).toFixed(2)}`, 400, y, { width: 150, align: "right" });
    y += 20;

    const totalAmount = Number(booking.totalAmount);
    const startingAmount = Number(baseAmount);

    if (totalAmount > startingAmount) {
      doc.text("Taxes & Fees", 50, y);
      doc.text(`INR ${(totalAmount - startingAmount).toFixed(2)}`, 400, y, { width: 150, align: "right" });
      y += 20;
    }

    doc.moveTo(50, y).lineTo(550, y).stroke(border);
    y += 10;

    doc.font("Helvetica-Bold").fillColor(textDark).fontSize(12);
    doc.text("Total", 300, y, { width: 100, align: "right" });
    doc.text(`INR ${totalAmount.toFixed(2)}`, 400, y, { width: 150, align: "right" });

    y += 40;
    const isPaid = booking.payments.some((payment: any) => payment.status === PaymentStatus.CAPTURED);
    if (isPaid) {
      doc.fillColor("#10B981").text("PAID IN FULL", 50, y);
    } else {
      doc.fillColor("#EF4444").text("PAYMENT PENDING", 50, y);
    }

    doc.font("Helvetica").fontSize(10).fillColor(textLight);
    doc.text("Thank you for choosing Veedufix!", 50, 700, { align: "center", width: 500 });

    doc.end();
  });
}
