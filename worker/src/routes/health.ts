import { json } from "../http";

export async function health(): Promise<Response> {
  return json({ status: "ok" });
}
