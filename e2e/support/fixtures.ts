import { test as base, expect, type BrowserContext, type Page } from "@playwright/test";
import { signIn } from "./auth";

type User = { email: string; password: string };

// ported from community_bookshelf e2e/support/fixtures.js
// pageAs(user) opens a second signed-in browser context for multi-user scenarios.
// Contexts are closed at teardown even when the test fails, since the suite runs
// serially in one worker and leaked contexts would pile up until the browser exits.
export const test = base.extend<{ pageAs: (user: User) => Promise<Page> }>({
  pageAs: async ({ browser }, use) => {
    const contexts: BrowserContext[] = [];
    await use(async (user) => {
      const context = await browser.newContext();
      contexts.push(context);
      const page = await context.newPage();
      await signIn(page, user);
      return page;
    });
    await Promise.all(contexts.map((context) => context.close()));
  },
});

export { expect };
