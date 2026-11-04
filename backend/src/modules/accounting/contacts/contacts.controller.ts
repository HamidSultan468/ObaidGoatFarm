import { Body, Controller, Get, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { AuditAction } from '../../../common/decorators/audit-action.decorator.js';
import { WorkspaceGuard } from '../../../common/guards/workspace.guard.js';
import { UpdateAccountStatusDto } from '../accounts/dto/update-account-status.dto.js';
import { ContactsService } from './contacts.service.js';
import { CreateContactDto } from './dto/create-contact.dto.js';
import { UpdateContactDto } from './dto/update-contact.dto.js';

@Controller('workspaces/:workspaceId/contacts')
@UseGuards(WorkspaceGuard)
export class ContactsController {
  constructor(private readonly contactsService: ContactsService) {}

  @Post()
  @AuditAction('accounting.contact.create')
  async create(@Param('workspaceId') workspaceId: string, @Body() dto: CreateContactDto) {
    return this.contactsService.create(workspaceId, dto);
  }

  @Get()
  async findAll(@Param('workspaceId') workspaceId: string) {
    return this.contactsService.findAll(workspaceId);
  }

  @Get(':contactId')
  async findOne(@Param('workspaceId') workspaceId: string, @Param('contactId') contactId: string) {
    return this.contactsService.findOne(workspaceId, contactId);
  }

  @Get(':contactId/ledger')
  async getLedger(@Param('workspaceId') workspaceId: string, @Param('contactId') contactId: string) {
    return this.contactsService.getLedger(workspaceId, contactId);
  }

  @Patch(':contactId')
  @AuditAction('accounting.contact.update')
  async update(
    @Param('workspaceId') workspaceId: string,
    @Param('contactId') contactId: string,
    @Body() dto: UpdateContactDto,
  ) {
    return this.contactsService.update(workspaceId, contactId, dto);
  }

  @Patch(':contactId/status')
  @AuditAction('accounting.contact.setStatus')
  async setActive(
    @Param('workspaceId') workspaceId: string,
    @Param('contactId') contactId: string,
    @Body() dto: UpdateAccountStatusDto,
  ) {
    return this.contactsService.setActive(workspaceId, contactId, dto.isActive);
  }
}
