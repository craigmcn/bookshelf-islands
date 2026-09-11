import { test, expect } from "@playwright/test";
import { signIn, users } from "./support/auth";

test.describe("Readings", () => {
  test("member sees their own shelf, including the seeded reading", async ({ page }) => {
    await signIn(page, users.member);
    await page.goto("/readings");
    const row = page.locator("tr", { has: page.getByRole("link", { name: "The Great Gatsby" }) });
    await expect(row).toBeVisible();
    await expect(row.locator("i.fa-star")).toHaveCount(4);
  });

  test("member can search and filter their shelf", async ({ page }) => {
    await signIn(page, users.member);
    await page.goto("/readings");
    await expect(page.getByRole("link", { name: "The Great Gatsby" })).toBeVisible();

    await page.getByLabel("Search").fill("gatsby");
    await expect(page.getByRole("link", { name: "The Great Gatsby" })).toBeVisible();

    await page.getByLabel("Search").fill("nonexistent title");
    await expect(page.getByText("No readings found.")).toBeVisible();

    await page.getByLabel("Search").fill("");
    await page.getByLabel("Status").selectOption("finished");
    await expect(page.getByText("No readings found.")).toBeVisible();

    await page.getByLabel("Status").selectOption("");
    await expect(page.getByRole("link", { name: "The Great Gatsby" })).toBeVisible();
  });

  test("member can log a reading with a status, rating, review, format, dates, and progress", async ({ page }) => {
    await signIn(page, users.member);
    await page.goto("/readings/new");

    await page.getByLabel("Book").selectOption({ label: "1984" });
    await page.getByLabel("Status").selectOption("finished");
    await page.getByLabel("Format").selectOption("ebook");
    await page.getByLabel("Started").fill("2026-01-05");
    await page.getByLabel("Finished").fill("2026-01-20");
    await page.getByRole("button", { name: "100%" }).click();
    await page.getByRole("group", { name: "Rating" }).getByRole("button", { name: "Five" }).click();
    await page.getByLabel("Review", { exact: true }).fill("Chillingly good.");
    await page.getByRole("switch", { name: /Review is/ }).uncheck();
    await page.getByRole("button", { name: "Create Reading" }).click();

    await expect(page.getByText("Chillingly good.")).toBeVisible();
    await expect(page.locator("dd i.fa-star")).toHaveCount(5);
    await expect(page.getByText("Ebook")).toBeVisible();
    await expect(page.getByText("100%")).toBeVisible();
    await expect(page.getByText("Private", { exact: true })).toBeVisible();
  });

  test("member can mark their Gatsby reading as DNF", async ({ page }) => {
    await signIn(page, users.member);
    await page.goto("/readings");
    const row = page.locator("tr", { has: page.getByRole("link", { name: "The Great Gatsby" }) });
    await row.getByRole("link").last().click();
    // Turbo's link prefetch can race a same-URL navigation and morph the just-rendered
    // form back to its original state if we interact before it settles — wait it out.
    await page.waitForLoadState("networkidle");

    await page.getByLabel("Status").selectOption("dnf");
    await page.getByRole("button", { name: "Update Reading" }).click();

    await expect(page.locator(".badge-status-dnf")).toBeVisible();
  });

  test("editing a reading updates the displayed rating", async ({ page }) => {
    await signIn(page, users.member);
    await page.goto("/readings");
    const row = page.locator("tr", { has: page.getByRole("link", { name: "1984" }) });
    await row.getByRole("link").last().click();

    await page.getByRole("group", { name: "Rating" }).getByRole("button", { name: "One" }).click();
    await page.getByRole("button", { name: "Update Reading" }).click();

    await expect(page.locator("dd i.fa-star")).toHaveCount(1);
  });

  test("member can start a re-read from a finished book", async ({ page }) => {
    await signIn(page, users.member);
    await page.goto("/readings");

    const rows = page.locator("tr", { has: page.getByRole("link", { name: "1984" }) });
    await expect(rows).toHaveCount(1);
    await rows.getByRole("button", { name: "Start a re-read" }).click();

    await expect(rows).toHaveCount(2);
    await expect(rows.filter({ hasText: "Want to read" })).toHaveCount(1);
  });

  test("moderator soft-deleting a reading removes it from the owner's shelf", async ({ page, browser }) => {
    await signIn(page, users.moderator);
    await page.goto("/admin/readings");

    const row = page.locator("tr", { has: page.getByRole("link", { name: "The Great Gatsby" }) });
    await row.getByRole("button", { name: "Delete" }).click();
    await row.getByRole("button", { name: "Yes" }).click();

    // the delete island removes the row via fetch, no page reload — badge and
    // fade should appear in place without navigating away from /admin/readings
    await expect(row).toHaveClass(/opacity-50/);
    await expect(row.getByText("Deleted")).toBeVisible();

    // fresh context instead of UI sign-out, to avoid racing the moderator's sign-out redirect
    const memberPage = await (await browser.newContext()).newPage();
    await signIn(memberPage, users.member);
    await memberPage.goto("/readings");
    await expect(memberPage.getByRole("link", { name: "The Great Gatsby" })).toHaveCount(0);
  });
});
