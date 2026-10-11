import { assertEquals } from "jsr:@std/assert";
import { costForEntry } from "./cost.ts";

Deno.test("first entry in the hour is free", () => {
  assertEquals(costForEntry(1), 0);
});

Deno.test("cost climbs 1/2/3 then plateaus", () => {
  assertEquals(costForEntry(2), 1);
  assertEquals(costForEntry(3), 2);
  assertEquals(costForEntry(4), 3);
  assertEquals(costForEntry(5), 3);
  assertEquals(costForEntry(50), 3);
});
