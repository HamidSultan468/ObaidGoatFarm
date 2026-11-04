import { Controller, Get, Param } from '@nestjs/common';
import { Public } from '../../../common/decorators/public.decorator.js';
import { ReceiptsService } from './receipts.service.js';

/** No :workspaceId — verifying a QR-coded receipt must work for anyone holding it, without credentials. */
@Controller('receipts')
export class ReceiptsController {
  constructor(private readonly receiptsService: ReceiptsService) {}

  @Public()
  @Get('verify/:code')
  async verify(@Param('code') code: string) {
    return this.receiptsService.verify(code);
  }
}
