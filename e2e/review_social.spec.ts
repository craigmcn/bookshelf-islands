import { test, expect } from "./support/fixtures";
import { signIn, users } from "./support/auth";

test.describe("Review likes and comments", () => {
  test("member can like and comment on another member's public review", async ({ page, pageAs }) => {
    // fresh context instead of reusing the moderator's page, since navigating a signed-in
    // page to /sign_in just redirects it away rather than showing the form
    const moderatorPage = await pageAs(users.moderator);
    await moderatorPage.goto("/readings/new");
    await moderatorPage.getByLabel("Book").selectOption({ label: "1984" });
    await moderatorPage.getByLabel("Status").selectOption({ label: "Finished" });
    await moderatorPage.getByLabel("Review", { exact: true }).fill("A moderator's take on Oceania.");
    await moderatorPage.getByRole("button", { name: "Create Reading" }).click();
    await expect(moderatorPage).toHaveURL(/\/readings\/\d+$/);
    const moderatorReadingUrl = moderatorPage.url();

    await signIn(page, users.member);
    await page.goto(moderatorReadingUrl);

    const likeButton = page.getByRole("button", { name: /^Like/ });
    await expect(likeButton).toBeVisible();
    await likeButton.click();
    await expect(page.getByRole("button", { name: "Liked (1)" })).toBeVisible();

    await page.getByPlaceholder("Add a comment…").fill("Great take on this one!");
    await page.getByRole("button", { name: "Post Comment" }).click();
    await expect(page.getByText("Great take on this one!")).toBeVisible();
    await expect(page.getByRole("link", { name: users.member.email })).toBeVisible();

    // failed posts show the island's own message, never a raw JSON parse error (#154)
    const html = { contentType: "text/html", body: "<!doctype html><title>Error</title>" };
    const failures = [
      { name: "HTML error page (500, NullByteGuard's 400)", response: { status: 400, ...html }, message: "Comment failed" },
      { name: "JSON validation error", response: { status: 422, json: { errors: ["Body is too long"] } }, message: "Body is too long" },
      { name: "signed out (Clearance's empty 401)", response: { status: 401, contentType: "application/json", body: "" }, message: "Comment failed" },
      { name: "Pundit denial (redirected to a 200 page)", response: { status: 200, ...html }, message: "Comment failed" },
    ];
    await expect(page.getByPlaceholder("Add a comment…")).toHaveValue(""); // else the fill below races the first post's reset
    await page.getByPlaceholder("Add a comment…").fill("This one is rejected.");
    for (const { name, response, message } of failures) {
      await page.route("**/review_comments", (route) => route.fulfill(response));
      await page.getByRole("button", { name: "Post Comment" }).click();
      await expect(page.locator("p.text-danger"), name).toHaveText(message);
      await page.unroute("**/review_comments");
    }

    // revert the reading created for this test (soft-deleting it also destroys the
    // like/comment above) so the fixture users stay stable for other specs/runs
    await moderatorPage.goto(moderatorReadingUrl);
    moderatorPage.once("dialog", (dialog) => dialog.accept());
    await moderatorPage.locator("button.btn-outline-danger", { hasText: "Delete" }).click();
  });
});
