import { readFile } from "node:fs/promises";
import { test, expect } from "./support/fixtures";
import { signIn, users } from "./support/auth";

test.describe("Shelf import and export", () => {
  // each needs a real browser: Turbo has to leave the .csv link alone and submit the multipart form
  test("member can download their shelf as CSV", async ({ page }) => {
    await signIn(page, users.member);
    await page.goto("/readings");

    const downloading = page.waitForEvent("download");
    await page.getByRole("link", { name: "Export CSV" }).click();
    const download = await downloading;

    expect(download.suggestedFilename()).toMatch(/^my-shelf-\d{4}-\d{2}-\d{2}\.csv$/);
    expect(await readFile(await download.path(), "utf8")).toContain("The Great Gatsby,F. Scott Fitzgerald");
  });

  test("member can upload a Goodreads CSV, skipping books already on their shelf", async ({ page }) => {
    await signIn(page, users.member);
    await page.goto("/readings");
    await page.getByRole("link", { name: "Import from Goodreads" }).click();

    // only an already-shelved book, so the import adds nothing and there's nothing to revert
    await page.getByLabel("Goodreads CSV export").setInputFiles({
      name: "goodreads.csv",
      mimeType: "text/csv",
      buffer: Buffer.from("Title,Author,Exclusive Shelf\nThe Great Gatsby,F. Scott Fitzgerald,read\n"),
    });
    await page.getByRole("button", { name: "Import" }).click();

    await expect(page).toHaveURL(/\/readings$/);
    await expect(page.getByText("Imported 0 book(s). Skipped 1 row(s)")).toBeVisible();
  });
});
