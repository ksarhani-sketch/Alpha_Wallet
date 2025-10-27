# Alpha Wallet Prototype

This repository contains a lightweight, front-end prototype for **Alpha Wallet**, a finance management experience focused on high-level visibility into cash flow, spending, and budgets.

## Features

- **Financial Overview** &mdash; Summary cards highlight balance, income, spending, and savings trends.
- **Budget Health** &mdash; Visualize monthly or annualized budgets with clear status indicators.
- **Transactions Table** &mdash; Filter and search recent transactions by merchant or category.
- **Quick Entry Form** &mdash; Add transactions on the fly to see how they impact your overview metrics.
- **Theme Toggle** &mdash; Switch between light and dark themes to review the interface in different contexts.

## Getting Started

No build tooling is required. Open `index.html` in your preferred browser to explore the prototype.

### Optional: Serve locally

You can serve the prototype via a basic static file server. For example, with Python installed:

```bash
python -m http.server 8000
```

Then visit [http://localhost:8000](http://localhost:8000) in your browser.

## Next Steps

- Connect the interface to live financial data sources.
- Expand budgeting to support custom categories and alerts.
- Layer in analytics (e.g., cashflow projections, investment tracking).
- Integrate authentication to personalize data per account holder.
