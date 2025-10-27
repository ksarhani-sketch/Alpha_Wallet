const transactions = [
  { id: 1, date: '2024-04-02', merchant: 'Fresh Market', category: 'Groceries', amount: -86.45 },
  { id: 2, date: '2024-04-05', merchant: 'Company Payroll', category: 'Salary', amount: 4200 },
  { id: 3, date: '2024-04-07', merchant: 'City Utilities', category: 'Utilities', amount: -132.19 },
  { id: 4, date: '2024-04-08', merchant: 'Coffee Collective', category: 'Dining', amount: -18.5 },
  { id: 5, date: '2024-04-09', merchant: 'Index Fund', category: 'Investments', amount: -450 },
  { id: 6, date: '2024-04-10', merchant: 'Ride Share', category: 'Transport', amount: -24.75 },
  { id: 7, date: '2024-04-11', merchant: 'Freelance Consulting', category: 'Side Income', amount: 820 },
  { id: 8, date: '2024-04-12', merchant: 'Streaming Plus', category: 'Subscriptions', amount: -14.99 },
];

const budgets = [
  { id: 'groceries', label: 'Groceries', limit: 600, spent: 312.4 },
  { id: 'dining', label: 'Dining Out', limit: 220, spent: 145.32 },
  { id: 'transport', label: 'Transport', limit: 180, spent: 96.9 },
  { id: 'wellness', label: 'Wellness & Fitness', limit: 150, spent: 65.0 },
];

const state = {
  transactions: [...transactions],
  budgets: [...budgets],
  filters: {
    query: '',
    category: 'all',
  },
  showAnnual: false,
  theme: window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light',
};

const formatCurrency = (value) => {
  const formatter = new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD',
    signDisplay: 'auto',
    maximumFractionDigits: 2,
  });
  return formatter.format(value);
};

const formatDate = (value) => {
  return new Intl.DateTimeFormat('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  }).format(new Date(value));
};

const getFilteredTransactions = () => {
  return state.transactions.filter((transaction) => {
    const matchQuery = state.filters.query
      ? `${transaction.merchant} ${transaction.category}`.toLowerCase().includes(state.filters.query)
      : true;
    const matchCategory =
      state.filters.category === 'all' ? true : transaction.category === state.filters.category;
    return matchQuery && matchCategory;
  });
};

const renderOverview = () => {
  const balance = state.transactions.reduce((acc, transaction) => acc + transaction.amount, 0);
  const income = state.transactions
    .filter((transaction) => transaction.amount > 0)
    .reduce((acc, transaction) => acc + transaction.amount, 0);
  const expenses = Math.abs(
    state.transactions
      .filter((transaction) => transaction.amount < 0)
      .reduce((acc, transaction) => acc + transaction.amount, 0),
  );
  const savingsRate = income === 0 ? 0 : Math.max(0, ((income - expenses) / income) * 100);

  const previousBalance = balance - (state.transactions.at(-1)?.amount ?? 0);
  const balanceDelta = balance - previousBalance;
  const expenseDelta = expenses - 680; // baseline comparison for prototype

  document.getElementById('balanceValue').textContent = formatCurrency(balance);
  document.getElementById('incomeValue').textContent = formatCurrency(income);
  document.getElementById('expenseValue').textContent = formatCurrency(expenses);
  document.getElementById('savingsRate').textContent = `${Math.round(savingsRate)}%`;

  const balanceChange = document.getElementById('balanceChange');
  const expenseChange = document.getElementById('expenseChange');

  balanceChange.textContent = `${balanceDelta >= 0 ? '▲' : '▼'} ${formatCurrency(Math.abs(balanceDelta))} vs. last transaction`;
  balanceChange.className = `stat-caption ${balanceDelta >= 0 ? 'positive' : 'negative'}`;

  expenseChange.textContent = `${expenseDelta <= 0 ? '▼' : '▲'} ${formatCurrency(Math.abs(expenseDelta))} vs. typical month`;
  expenseChange.className = `stat-caption ${expenseDelta <= 0 ? 'positive' : 'negative'}`;
};

const renderBudgets = () => {
  const list = document.getElementById('budgetList');
  const template = document.getElementById('budgetTemplate');
  list.innerHTML = '';

  state.budgets.forEach((budget) => {
    const node = template.content.cloneNode(true);
    const limit = state.showAnnual ? budget.limit * 12 : budget.limit;
    const spent = state.showAnnual ? budget.spent * 12 : budget.spent;
    const status = spent >= limit ? 'At risk of overspending' : 'On track';

    node.querySelector('.budget-name').textContent = budget.label;
    node.querySelector('.budget-amount').textContent = `${formatCurrency(spent)} / ${formatCurrency(limit)}`;
    node.querySelector('.budget-progress-bar').style.width = `${Math.min((spent / limit) * 100, 100)}%`;
    node.querySelector('.budget-status').textContent = status;
    node.querySelector('.budget-status').className = `budget-status ${spent >= limit ? 'warning' : 'ok'}`;

    list.appendChild(node);
  });
};

const renderTransactions = () => {
  const body = document.getElementById('transactionBody');
  const emptyState = document.getElementById('transactionEmpty');
  const template = document.getElementById('transactionRowTemplate');
  body.innerHTML = '';

  const rows = getFilteredTransactions();
  emptyState.hidden = rows.length > 0;

  rows
    .sort((a, b) => new Date(b.date) - new Date(a.date))
    .forEach((transaction) => {
      const node = template.content.cloneNode(true);
      node.querySelector('[data-field="date"]').textContent = formatDate(transaction.date);
      node.querySelector('[data-field="merchant"]').textContent = transaction.merchant;
      node.querySelector('[data-field="category"]').textContent = transaction.category;
      node.querySelector('[data-field="amount"]').textContent = formatCurrency(transaction.amount);
      node.querySelector('[data-field="amount"]').classList.toggle('negative', transaction.amount < 0);
      node.querySelector('[data-field="amount"]').classList.toggle('positive', transaction.amount > 0);
      body.appendChild(node);
    });
};

const populateCategories = () => {
  const categories = Array.from(new Set(state.transactions.map((transaction) => transaction.category)));
  const filter = document.getElementById('categoryFilter');
  const formSelect = document.getElementById('formCategory');

  filter.innerHTML = '<option value="all">All categories</option>';
  formSelect.innerHTML = '';

  categories.forEach((category) => {
    const option = document.createElement('option');
    option.value = category;
    option.textContent = category;
    filter.appendChild(option.cloneNode(true));
    formSelect.appendChild(option);
  });
};

const handleTransactionForm = (event) => {
  event.preventDefault();
  const formData = new FormData(event.target);
  const amount = Number.parseFloat(formData.get('amount'));

  if (Number.isNaN(amount)) {
    alert('Please enter a valid amount');
    return;
  }

  const id = typeof crypto !== 'undefined' && crypto.randomUUID ? crypto.randomUUID() : `txn-${Date.now()}`;

  state.transactions.push({
    id,
    date: formData.get('date'),
    merchant: formData.get('merchant'),
    category: formData.get('category'),
    amount,
  });

  event.target.reset();
  populateCategories();
  renderOverview();
  renderTransactions();
};

const handleSearch = (event) => {
  state.filters.query = event.target.value.trim().toLowerCase();
  renderTransactions();
};

const handleCategoryFilter = (event) => {
  state.filters.category = event.target.value;
  renderTransactions();
};

const handleAnnualToggle = (event) => {
  state.showAnnual = event.target.checked;
  renderBudgets();
};

const handleThemeToggle = () => {
  state.theme = state.theme === 'dark' ? 'light' : 'dark';
  applyTheme();
};

const applyTheme = () => {
  document.body.classList.toggle('dark', state.theme === 'dark');
  document.getElementById('themeToggle').textContent = state.theme === 'dark' ? '☀️' : '🌙';
};

const init = () => {
  document.getElementById('transactionForm').addEventListener('submit', handleTransactionForm);
  document.getElementById('transactionSearch').addEventListener('input', handleSearch);
  document.getElementById('categoryFilter').addEventListener('change', handleCategoryFilter);
  document.getElementById('showAnnual').addEventListener('change', handleAnnualToggle);
  document.getElementById('themeToggle').addEventListener('click', handleThemeToggle);

  populateCategories();
  renderOverview();
  renderBudgets();
  renderTransactions();
  applyTheme();
};

document.addEventListener('DOMContentLoaded', init);
