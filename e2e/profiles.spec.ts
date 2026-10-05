import { test, expect, type Browser } from "@playwright/test";
import { signIn, users } from "./support/auth";

// Profile URLs are /users/:id, and nothing in the UI a member can reach
// exposes another member's numeric id directly — so each test looks it up
// via a throwaway admin context first (admin/users links to it), then
// proceeds with the real member-facing interaction under test.
async function lookUpUserId(browser: Browser, email: string): Promise<string> {
  const adminContext = await browser.newContext();
  const adminPage = await adminContext.newPage();
  await signIn(adminPage, users.admin);
  await adminPage.goto("/admin/users");

  const href = await adminPage
    .getByRole("row", { name: new RegExp(email) })
    .getByRole("link", { name: "Edit Roles" })
    .getAttribute("href");
  await adminContext.close();

  const match = /\/admin\/users\/(\d+)\/edit/.exec(href ?? "");
  if (!match) throw new Error(`Could not find a user id for ${email}`);
  return match[1];
}

test.describe("Profiles", () => {
  test("member's profile shows their favorite genres and public reviews", async ({ page, browser }) => {
    await signIn(page, users.member);
    await page.goto("/account/edit");
    await page.getByLabel("Favorite Genres").fill("fantasy");
    await page.getByRole("button", { name: "Save Changes" }).click();

    const memberId = await lookUpUserId(browser, users.member.email);
    await page.goto(`/users/${memberId}`);
    await expect(page.getByRole("link", { name: "fantasy" })).toBeVisible();
    await expect(page.getByText("A great read.")).toBeVisible();

    // revert so the fixture user stays stable for other specs/runs
    await page.goto("/account/edit");
    await page.getByLabel("Favorite Genres").fill("");
    await page.getByRole("button", { name: "Save Changes" }).click();
  });

  test("member can follow and unfollow another member from their profile", async ({ page, browser }) => {
    const moderatorId = await lookUpUserId(browser, users.moderator.email);

    await signIn(page, users.member);
    await page.goto(`/users/${moderatorId}`);

    await page.getByRole("button", { name: "Follow" }).click();
    await expect(page.getByRole("button", { name: "Following" })).toBeVisible();

    await page.getByRole("link", { name: "Followers" }).click();
    await expect(page.getByRole("heading", { name: /Followers/ })).toBeVisible();
    await expect(page.locator("#main-content").getByRole("link", { name: users.member.email })).toBeVisible();

    await page.goBack();
    await page.getByRole("button", { name: "Following" }).click();
    await expect(page.getByRole("button", { name: "Follow" })).toBeVisible();
  });
});
