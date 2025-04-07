@Metadata.allowExtensions: true
@EndUserText.label: '###GENERATED Core Data Service Entity'
@AccessControl.authorizationCheck: #CHECK
@Search.searchable: true
@ObjectModel.semanticKey: [ 'TravelId' ]
define root view entity ZC_RAP100_ATRAVMFB000
  provider contract transactional_query
  as projection on ZR_RAP100_ATRAVMFB001
{
@Search.defaultSearchElement: true
@Search.fuzzinessThreshold: 0.90
  key TravelId,
  @Search.defaultSearchElement: true
  @ObjectModel.text.element : ['AgencyName']
  @Consumption.valueHelpDefinition: [{ entity : { name : '/DMO/I_Agency' , element : 'AgencyID' }, useForValidation: true  }]
  AgencyId,
  _Agency.Name as AgencyName,
  @Search.defaultSearchElement: true
  @ObjectModel.text.element: [ 'CustomerName' ]
  @Consumption.valueHelpDefinition: [{ entity : { name : '/DMO/I_Customer' , element : 'CustomerID' },useForValidation: true }]
  CustomerId,
  _Customer.LastName as CustomerName,
  BeginDate,
  EndDate,
  BookingFee,
  TotalPrice,
  @Semantics.currencyCode: true
  @Consumption.valueHelpDefinition: [{ entity : { name : 'I_CurrencyStdVH' , element : 'Currency' }, useForValidation: true  }]
  CurrencyCode,
  Description,
 @ObjectModel.text.element: [ 'OverallStatusText' ]
  @Consumption.valueHelpDefinition: [{ entity : { name : '/DMO/I_Overall_Status_VH' , element : 'OverallStatus' }, useForValidation: true  }]
  OverallStatus,
  _Overallstatus._Text.Text as OverallStatusText : localized,
  @Semantics.largeObject : { mimeType : 'MimeType',
                             fileName : 'FileName',
                             acceptableMimeTypes: [ 'image/png' , 'image/jpeg','application/pdf' ],
                             contentDispositionPreference: #ATTACHMENT }
  Attachment,
    @Semantics.mimeType:true
  MimeType,
  FileName,
  CreatedBy,
  CreatedAt,
  LocalLastChangedBy,
  LocalLastChangedAt,
  LastChangedAt
  
  
}
