import { Module } from '@nestjs/common';
import { AccountsController } from './accounts/accounts.controller.js';
import { AccountsService } from './accounts/accounts.service.js';
import { BudgetsController } from './budgets/budgets.controller.js';
import { BudgetsService } from './budgets/budgets.service.js';
import { ContactsController } from './contacts/contacts.controller.js';
import { ContactsService } from './contacts/contacts.service.js';
import { LedgerService } from './ledger/ledger.service.js';
import { ReceiptsController } from './receipts/receipts.controller.js';
import { ReceiptsService } from './receipts/receipts.service.js';
import { RecurringController } from './recurring/recurring.controller.js';
import { RecurringService } from './recurring/recurring.service.js';
import { ReportsController } from './reports/reports.controller.js';
import { ReportsService } from './reports/reports.service.js';
import { TransactionsController } from './transactions/transactions.controller.js';
import { TransactionsService } from './transactions/transactions.service.js';

@Module({
  controllers: [
    AccountsController,
    ContactsController,
    TransactionsController,
    ReportsController,
    BudgetsController,
    RecurringController,
    ReceiptsController,
  ],
  providers: [
    LedgerService,
    AccountsService,
    ContactsService,
    TransactionsService,
    ReportsService,
    BudgetsService,
    RecurringService,
    ReceiptsService,
  ],
  // AccountsService is used by WorkspacesModule to seed the default chart of accounts on creation.
  exports: [AccountsService, LedgerService, TransactionsService, ReportsService],
})
export class AccountingModule {}
