@AccessControl.authorizationCheck: #CHECK
@Metadata.allowExtensions: true
@EndUserText.label: '###GENERATED Core Data Service Entity'
define root view entity ZR_RAP100_ATRAVMFB001
  as select from zrap100_atravmfb as TRAVEL
  association[0..1] to /DMO/I_Agency as _Agency on $projection.AgencyId = _Agency.AgencyID
  association[0..1] to /DMO/I_Customer as _Customer on $projection.CustomerId = _Customer.CustomerID
  association[0..1] to /DMO/I_Overall_Status_VH as _Overallstatus on $projection.OverallStatus = _Overallstatus.OverallStatus
  association[0..1] to I_Currency as _Currency on $projection.CurrencyCode = _Currency.Currency
{
  key travel_id as TravelId,
  agency_id as AgencyId,
  customer_id as CustomerId,
  begin_date as BeginDate,
  end_date as EndDate,
  @Semantics.amount.currencyCode: 'CurrencyCode'
  booking_fee as BookingFee,
  @Semantics.amount.currencyCode: 'CurrencyCode'
  total_price as TotalPrice,
  @Consumption.valueHelpDefinition: [ {
    entity.name: 'I_CurrencyStdVH', 
    entity.element: 'Currency', 
    useForValidation: true
  } ]
  currency_code as CurrencyCode,
  description as Description,
  overall_status as OverallStatus,
  attachment as Attachment,
  mime_type as MimeType,
  file_name as FileName,
  @Semantics.user.createdBy: true
  created_by as CreatedBy,
  @Semantics.systemDateTime.createdAt: true
  created_at as CreatedAt,
  @Semantics.user.localInstanceLastChangedBy: true
  local_last_changed_by as LocalLastChangedBy,
  @Semantics.systemDateTime.localInstanceLastChangedAt: true
  local_last_changed_at as LocalLastChangedAt,
  @Semantics.systemDateTime.lastChangedAt: true
  last_changed_at as LastChangedAt,
  
  _Currency,
  _Overallstatus,
  _Agency,
  _Customer
  
}
