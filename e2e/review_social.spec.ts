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

    // an HTML error page (e.g. NullByteGuard's 400.html) must show a readable message, not a JSON parse error (#154)
    await page.route("**/review_comments", (route) =>
      route.fulfill({ status: 400, contentType: "text/html", body: "<!doctype html><title>Bad request</title>" }),
    );
    await expect(page.getByPlaceholder("Add a comment…")).toHaveValue(""); // the first post's reset has landed
    await page.getByPlaceholder("Add a comment…").fill("This one is rejected.");
    await page.getByRole("button", { name: "Post Comment" }).click();
    await expect(page.getByText("Comment failed")).toBeVisible();
    await page.unroute("**/review_comments");

    // a JSON validation error still shows the server's own messages
    await page.route("**/review_comments", (route) =>
      route.fulfill({ status: 422, json: { errors: ["Body is too long"] } }),
    );
    await page.getByRole("button", { name: "Post Comment" }).click();
    await expect(page.getByText("Body is too long")).toBeVisible();
    await page.unroute("**/review_comments");

    // revert the reading created for this test (soft-deleting it also destroys the
    // like/comment above) so the fixture users stay stable for other specs/runs
    await moderatorPage.goto(moderatorReadingUrl);
    moderatorPage.once("dialog", (dialog) => dialog.accept());
    await moderatorPage.locator("button.btn-outline-danger", { hasText: "Delete" }).click();
  });
});
