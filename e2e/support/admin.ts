import type { Browser } from "@playwright/test";
import { signIn, users } from "./auth";

// Profile URLs are /users/:id, and nothing in the UI a member can reach
// exposes another member's numeric id directly — so each caller looks it up
// via a throwaway admin context first (admin/users links to it), then
// proceeds with the real member-facing interaction under test.
export async function lookUpUserId(browser: Browser, email: string): Promise<string> {
  const adminContext = await browser.newContext();
  try {
    const adminPage = await adminContext.newPage();
    await signIn(adminPage, users.admin);
    await adminPage.goto("/admin/users");

    // exact cell match, not a RegExp of the email — "." and "+" would otherwise
    // be regex metacharacters and could match the wrong row
    const href = await adminPage
      .getByRole("row")
      .filter({ has: adminPage.getByRole("cell", { name: email, exact: true }) })
      .getByRole("link", { name: "Edit Roles" })
      .getAttribute("href");

    const match = /\/admin\/users\/(\d+)\/edit/.exec(href ?? "");
    if (!match) throw new Error(`Could not find a user id for ${email}`);
    return match[1];
  } finally {
    await adminContext.close();
  }
}
