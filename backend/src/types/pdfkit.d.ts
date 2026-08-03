declare module "pdfkit" {
  import { Writable } from "stream";

  export default class PDFDocument extends Writable {
    constructor(options?: any);

    on(event: "data", listener: (buffer: Buffer) => void): this;
    on(event: "end", listener: () => void): this;
    on(event: "error", listener: (error: Error) => void): this;
    on(event: string, listener: (...args: any[]) => void): this;

    fontSize(size: number): this;
    fillColor(color: string): this;
    text(text: string, x?: number | object, y?: number | object, options?: object): this;
    moveDown(lines?: number): this;
    moveUp(lines?: number): this;
    moveTo(x: number, y: number): this;
    lineTo(x: number, y: number): this;
    stroke(color?: string): this;
    font(name: string): this;
    end(): this;
  }
}
