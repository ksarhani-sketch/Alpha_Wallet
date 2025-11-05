# Alpha Wallet Personal Finance Application Scope of Work

This scope of work (SOW) outlines the tasks required to transform the Alpha Wallet demo into a full-fledged personal finance application. The current demo already includes transaction entry, wallets, categories, budgets, recurring templates, and basic settings (theme, reminders). The new version will expand functionality across authentication, budgeting, financial planning, internationalization, and integrations. Sections are organized by feature with implementation notes and references from industry sources.

## 1. User Authentication

**Goal:** Provide secure user accounts supporting multiple devices and allow differentiated access to data.

**Tasks:**

- Choose authentication method: Integrate a secure authentication provider (e.g., Firebase Auth, Auth0, or Cognito). Implement email/password sign-up, login, and password reset. Consider social logins (Google, Apple ID, etc.) for faster onboarding.
- Backend endpoint: Add `/auth` endpoints on the Node/TypeScript API for registration, login, and token refresh. Protect existing finance endpoints (budgets, transactions, wallets) with JWT tokens. Update OpenAPI spec accordingly.
- Local vs. remote data: When offline or using the free tier, persist data locally using Hive/SQLite. Upon login, sync data with the cloud. Provide a migration path from the current demo’s sample data to the authenticated user’s database.
- State management: In Flutter, create authentication providers using Riverpod. Display login/sign-up screens prior to the finance features. On app launch, check token validity and navigate to the appropriate screen.

## 2. Category & Budget Enhancements

### 2.1 Add Additional Categories & Budget Limits

**Goal:** Allow users to create custom categories while adding transactions. Each category can have its own budget.

**Tasks:**

- UI changes: Modify the Quick Add sheet to include an “Add new category” button. This opens a form to specify name, icon, and category type (expense/income). On save, create the category and optionally set a budget limit. The existing category picker in `quick_add_sheet.dart` already lists categories; extend it to include user-created items.
- Backend updates: Add endpoints to create/update/delete categories. When creating a new category, optionally include a `defaultBudgetLimit`. Update budgets API to accept `categoryId` and `limit` (existing OpenAPI spec already allows `categoryId`, `limit`, `alertThreshold`, and `rollover`). Adjust the database schema to support user-defined categories.
- Budget model update: Expand the Budget model (currently supports `period`, `limit`, `currency`, and `rollover`) to include a `categoryId` and support dynamic creation from the client.

### 2.2 Adjust Budget Limits Manually

**Goal:** Let users edit budget limits or set budgets without adding a transaction. Currently budgets are defined in sample data; manual editing is required.

**Tasks:**

- Budget settings page: Create a budget management screen where users see all budgets (category-specific or general). Each budget card should show spent, limit, and remaining, similar to the existing `budget_progress.dart` UI. Provide controls to modify the limit, change period (weekly, monthly, custom), and adjust alert thresholds.
- Backend: Implement update/delete endpoints for budgets. Validate positive numeric values for `limit` and `alertThreshold` as in the existing API.
- Rollover rules: If the budget is set to roll over, unspent amounts carry into the next period. Provide an option to let unspent budgets expire at period end or accumulate (“rollover rules”). The envelope budgeting method suggests leftover funds can either be saved for future periods or repurposed.

## 3. Wallet Management

**Goal:** Allow users to add, rename, or remove wallets (bank accounts, cash, credit cards). Each wallet has its own balance, currency, and account type.

**Tasks:**

- UI: Add a Wallets screen listing existing wallets. Provide actions to add a wallet (name, account type, currency, initial balance), edit, or delete. When deleting a wallet, prompt the user to select a replacement wallet for transactions or choose to delete associated transactions.
- Backend: Extend the API to create/update/delete wallets. When a wallet is removed, handle cascading effects on transactions and budgets.
- Multiple currencies: Each wallet stores transactions in its own currency. Provide currency selection from ISO list; default is USD. Maintain exchange rates (use an API like OpenExchangeRates) for computing aggregate balances.
- Balance calculations: Update providers to compute total balance across all wallets in the user’s base currency. Provide toggles to view balances per wallet or aggregated.

## 4. Credit Card Limit & Bill Payment

**Goal:** Support credit card tracking: set a spending limit, alert when approaching limit, record payments.

**Tasks:**

- Credit card limit: Extend the wallet model to include an optional `creditLimit`. On each transaction addition, calculate the running balance and trigger an alert when the spending approaches or exceeds the limit. Leverage existing budget alert functionality (`alertThreshold`) to implement this logic.
- Billing category: Add a “Credit Card Payment” category (income negative or transfer) that reduces the credit card balance. Provide a quick-pay button on the wallet screen to add a payment transaction from a specified funding wallet.
- Alerts: Display notifications when the credit card balance exceeds the limit. Provide push notifications if allowed.

## 5. Recurring Transactions Management

**Goal:** Allow users to create, edit, or cancel recurring transactions. Existing sample data includes recurring templates for rent and salary.

**Tasks:**

- Recurring transaction list: Create a screen listing all recurring transactions with details (amount, category, next occurrence, end date). Provide actions to pause, edit, or delete. Use the existing `RecurringTemplate` model from the sample data.
- UI integration: In the Quick Add sheet, add an option to “Make this recurring.” When checked, prompt for frequency (weekly, monthly, annually, custom), start date, end date, and auto-increment to budgets.
- Backend: Add endpoints to manage recurring transactions. Implement a scheduler (cron job or serverless function) that generates actual transactions on their due date. Offer skip or snooze actions from the Bill Calendar (see section 9).

## 6. Additional Income Sources

**Goal:** Permit users to record other income streams (investments, dividends, interest, side gigs). Each income can be recurring or one-off.

**Tasks:**

- Categories: Create default categories for different income types (Investment Profit, Dividends, Freelance, etc.). Allow users to create new income categories as described in section 2.1.
- Recurring income: When creating an income transaction, allow marking it as recurring. Integrate into the recurring transaction engine.
- Reports: Update income reports to categorize and sum by income type. Show income vs. expenses and net savings on the overview page.

## 7. Overview Page Enhancements

**Goal:** Provide an informative dashboard summarizing monthly spending, savings, and budgets.

**Tasks:**

- Monthly view: Add a toggle on the overview to switch between the current month, previous month, and custom ranges. Display charts for spending vs. income, savings rate, and budget progress.
- Savings display: Show total savings (income minus expenses) and savings goals progress. Provide a breakdown by wallets or categories.
- Net worth summary: If the user has enabled net worth tracking (see section 13), show total assets minus liabilities. Highlight monthly changes.

## 8. Language and Currency Settings

**Goal:** Allow users to change the app language and primary currency from the settings. The demo currently defaults to English and follows system language; Arabic RTL translations are planned.

**Tasks:**

- Language selection: Add a language picker in Settings. On selection, load the appropriate localization files without requiring the system language to change. The default language remains English. Implement ARB (Application Resource Bundle) files for translations.
- Multi-currency base: Provide a setting for the user’s base currency (used for aggregated balances and budgets). Implement conversions for existing transactions and budgets when the base currency changes and warn the user about possible data implications.
- Per-wallet currency: Each wallet retains its own currency; conversions occur during aggregation using up-to-date exchange rates.

## 9. Bill Calendar

**Goal:** Provide a month-view calendar showing upcoming bills, subscriptions, and recurring transactions.

**Tasks:**

- Calendar UI: Create a calendar component (month view) listing recurring transactions and due dates. Mark paid transactions in green and upcoming ones in blue.
- Integration with recurring engine: Display all recurring transactions and bills. Allow users to mark them as paid, skip, or snooze. Provide quick links to view recent payments or edit details. When clicking an upcoming expense, show a pop-up with past amounts.
- Alerts: Send notifications a set number of days before the bill is due. Integrate with the reminders feature already in the demo.
- Credit card due dates: Include credit card statements with minimum payments and due dates.

## 10. Envelope Budgets & Roll-Over Rules

**Goal:** Implement envelope budgeting and rollover logic.

**Tasks:**

- Envelope creation: Allow users to allocate part of their paycheque into envelopes on payday. On each pay period, deposit funds into envelopes (similar to budgets but with dedicated balance tracking). Use the existing budget model with a rollover flag.
- Rollover options: Provide settings on each envelope to allow leftover funds to roll over or expire at period end. Offer manual transfer of leftover funds to other envelopes or savings goals.
- Visual indicators: Show envelope balances on the dashboard and quick add sheet. When an envelope is depleted, disable spending from that category until the next deposit.
- Backend changes: Implement an Envelope entity (or extend the budget model) to track allocated amounts, current balance, and rollover rule. Process payday distribution via recurring templates.

## 11. Rules Engine for Auto-Categorization

**Goal:** Automatically categorize transactions using rules and machine learning.

**Tasks:**

- Keyword rules: Build a rules engine that matches transaction descriptions to categories (e.g., “Uber” → Transport). Users can add, edit, or delete rules, assign confidence scores, and choose whether the rule is applied automatically or needs confirmation.
- Machine learning: Consider training a lightweight classification model (e.g., Naive Bayes) on historical user data to suggest categories. Combine rules with ML predictions, weighting by confidence. Provide suggestions on the quick add sheet; allow the user to accept or override. Over time, the model learns from corrections.
- Backend: Add endpoints to manage rules and store user corrections. Use asynchronous tasks to run classification when transactions are imported.
- UI: In the transaction list, display the predicted category with a confidence indicator. Offer a “Review uncategorized” section where users can batch confirm categories.
- Privacy: Ensure that categorization occurs locally or on the server with user consent. Provide the option to disable automatic categorization.

## 12. Savings Goals & Sinking Funds

**Goal:** Help users allocate money toward future purchases.

**Tasks:**

- Goals model: Create a `SavingsGoal` entity with fields: name, target amount, current balance, associated wallet(s), percentage allocation, deadline, and optional notes. Provide a `recurringContribution` to auto-transfer funds each period.
- UI: Implement a Savings Goals page listing all goals with progress bars. Each goal shows target, current savings, percentage complete, and time remaining. Provide actions to add contributions, withdraw funds for the intended purchase, edit, or delete the goal.
- Auto-allocation: Offer the option to automatically allocate a percentage of incoming income or specific envelopes to goals. For example, 10% of each salary deposit goes toward a “Vacation” fund.
- Sinking funds: Use goals as sinking funds for irregular bills. Provide a template wizard to set up such plans.
- Integration: When the goal is fully funded and the purchase occurs, allow converting the goal into a completed transaction and optionally start a new cycle.

## 13. What-If Planning (Scenario Analysis)

**Goal:** Let users simulate financial outcomes under different assumptions.

**Tasks:**

- Planning module: Build a sandbox where users can create “what-if” scenarios. Inputs include: new recurring expenses/incomes, changes in salary, interest rates, or savings contributions. Output is a projection of monthly cash flow and savings over a chosen horizon.
- Simulation engine: Use the existing budget and recurring transaction data to project baseline cash flow. When a scenario is applied, adjust the projection accordingly. Provide visual charts (e.g., line chart showing baseline vs. scenario) and summary statistics. Include best-case/worst-case/likely toggles to account for different assumptions.
- Sensitivity options: Allow users to adjust variables like price inflation, income growth, or interest rates. Provide quick presets (optimistic, pessimistic).
- Persistence: Save scenarios for later comparison. Offer export to PDF or share via link.

## 14. Net-Worth Tracker

**Goal:** Aggregate assets and liabilities to compute total net worth.

**Tasks:**

- Assets & liabilities: Create data models for assets (cash, bank accounts, investments, property, vehicles) and liabilities (credit cards, loans, mortgages). Use the existing wallets to represent some accounts; add separate entries for investment accounts, real estate, and other assets.
- Net worth dashboard: Provide a screen summarizing total assets, total liabilities, and net worth over time. Show historical changes using line charts. Provide breakdown by asset type.
- Asset valuation: Integrate with third-party APIs (e.g., stock and crypto price feeds, property value estimators) to update asset values. Allow manual entry for assets without market feeds.
- Multi-currency: Convert asset values into base currency using up-to-date exchange rates. Provide toggles to display values in original currencies.
- Integration with budgets: Show net worth along with budget progress on the overview page. Provide insights about how spending, saving, and investing affect net worth.

## 15. Bill Calendar Integration with Recurring & Net-Worth Modules

Ensure that the Bill Calendar works with net worth (by updating liabilities when bills are paid) and with savings goals (showing future contributions as outflows).

## 16. Custom Dashboards & Widgets

**Goal:** Provide customizable dashboard widgets so users can prioritize the information most relevant to them.

**Tasks:**

- Widget system: Develop a dashboard architecture where each widget is a component that fetches specific data (e.g., spending today, budget remaining, upcoming bills, savings goal progress). Users can add, remove, reorder, or resize widgets.
- Predefined widgets: Implement default widgets such as Today’s Spend, Remaining This Month, Next Bill, Savings Goal Progress, and Net Worth Trend.
- Home widgets (iOS/Android): Provide OS-level widgets showing summary data on the device home screen. Follow platform guidelines for privacy (mask amounts if privacy mode is active).

## 17. Receipt Attachments & OCR

**Goal:** Allow users to attach receipts and leverage OCR for data extraction.

**Tasks:**

- Attachment model: Extend the transaction model to include an array of attachments (image or PDF). Create an endpoint to upload attachments and generate pre-signed URLs. Store metadata such as file type, size, and extracted text.
- OCR integration: Use an OCR service (e.g., Google Cloud Vision, AWS Textract) to extract text from uploaded receipts. After OCR, parse merchant name, date, total amount, and line items. Suggest categories based on recognized text (use the auto-categorization engine). Store the extracted data for search.
- UI: In the transaction detail page, display thumbnails of attached receipts and allow opening them. Provide an “Add attachment” button in the Quick Add and edit screens. After upload, show extracted fields and allow the user to confirm or edit.
- Search: Enable full-text search over receipt contents and attachments. Provide filters and integrate with export to accounting.

## 18. Privacy Modes

**Goal:** Allow users to mask balances and amounts when needed.

**Tasks:**

- Quick hide: Add a toggle (eye icon) in the app’s top bar to mask all balances and amounts across the UI. When activated, replace amounts with placeholder symbols (e.g., “••••”). The setting should persist until the user closes the app.
- Selective masking: Provide options to hide only specific wallets or categories.
- Screen-sharing detection: Optionally integrate with OS APIs to detect when screen sharing/recording is active and automatically enable privacy mode.
- Settings: Add a Privacy section in Settings to control the default behavior.

## 19. Export to Accounting (CSV/QuickBooks/Xero)

**Goal:** Enable users to export their data to accounting software.

**Tasks:**

- CSV export: Provide an export feature in Settings. Users can select a date range and choose the export format (CSV, QBO, QIF). The CSV should include columns for date, description, category, amount, wallet, currency, and notes. Offer mapping presets for popular accounting systems. Allow manual field mapping.
- Reconciliation metadata: Include optional fields (beginning balance, ending balance, statement period) to support reconciliation. Provide instructions for reconciling data.
- Attachments: Offer an option to include receipt attachments in a ZIP file or embed them into the export with references in the CSV.
- Integration with QuickBooks/Xero: Provide integration via APIs if possible (OAuth). Users can connect their accounting software and push transactions directly. Map categories to chart-of-accounts items.

## 20. Additional Considerations

### 20.1 Data Security & Privacy

- Implement encryption at rest and in transit for all user data. Follow industry best practices for storing tokens and credentials.
- Comply with relevant data-protection laws (e.g., GDPR, CCPA). Provide a privacy policy and allow users to export or delete their data.

### 20.2 Performance & Scalability

- Migrate local storage to a scalable cloud database (e.g., Firestore, PostgreSQL). Use pagination and caching on the frontend to handle large datasets.
- Build asynchronous background tasks for long-running operations (OCR, scenario simulations, exports).

### 20.3 Testing & QA

- Write unit tests for each new model and provider. Create integration tests for authentication and payment flows.
- Test UI across different languages (LTR and RTL) and currencies. Validate currency conversions and rounding.

### 20.4 Documentation & Support

- Update the OpenAPI specification to include all new endpoints and models. Provide in-app tooltips and a help center.
- Create onboarding tutorials demonstrating new features (savings goals, scenario planning, privacy mode, etc.).

## Conclusion

This scope of work lays out a comprehensive roadmap to transform Alpha Wallet from a demo into a robust personal finance platform. By adding user authentication, enhanced budgeting, wallet management, credit card limits, recurring transaction management, additional income sources, language and currency customization, envelope and savings features, automatic categorization, scenario planning, net-worth tracking, bill calendars, custom dashboards, receipt attachments, privacy modes, and accounting exports, the app will compete with leading solutions. Each feature is grounded in practices observed in existing apps and supported by research citations to justify their inclusion and implementation details.
