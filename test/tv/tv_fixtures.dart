import 'package:pos_core/pos_core.dart';
import 'package:timma_kds/tv/domain/tv_phrases.dart';

/// Shared builders for the TV tests.
final DateTime t0 = DateTime.utc(2026, 11, 27, 12);

PosOrder order(
  String id, {
  String status = PosOrderStatus.preparing,
  String source = PosOrderSource.kiosk,
  DateTime? placed,
  DateTime? changed,
  int? number = 7,
  String? dailyCode,
}) => PosOrder(
  clientId: id,
  branchId: 'branch-1',
  origin: PosOrderOrigin.remote,
  source: source,
  mode: PosOrderMode.pickup,
  status: status,
  paymentStatus: PosPaymentStatus.paid,
  paymentMethod: PosPaymentMethod.payAtCounter,
  deviceSeq: 1,
  subtotal: 2000,
  discount: 0,
  deliveryFee: 0,
  total: 2000,
  placedAtDevice: placed ?? t0,
  statusChangedAt: changed ?? t0,
  ticketNumber: number,
  dailyCode: dailyCode,
);

PosOrderLine line(String name, int qty, {String? variant}) => PosOrderLine(
  lineNo: 1,
  productId: 'p-$name',
  nameFr: name,
  nameEn: name,
  unitPrice: 1000,
  quantity: qty,
  lineTotal: 1000 * qty,
  variantNameFr: variant,
);

/// The French sentences, as the arb defines them.
final TvPhrases frPhrases = TvPhrases(
  preparing: (String c) => 'Commande $c en préparation.',
  ready: (String c) => 'Commande $c est prête.',
  line: (int q, String n) => '$q $n',
  repeat: (String c) => 'Je répète : $c',
);
