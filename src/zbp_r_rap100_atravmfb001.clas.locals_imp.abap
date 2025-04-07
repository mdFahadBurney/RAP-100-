CLASS lhc_zr_rap100_atravmfb001 DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF travel_status,
        open     TYPE c LENGTH 1 VALUE 'O', "Open
        accepted TYPE c LENGTH 1 VALUE 'A', "Accepted
        rejected TYPE c LENGTH 1 VALUE 'X', "Rejected
      END OF travel_status.

    METHODS:
      get_global_authorizations FOR GLOBAL AUTHORIZATION
        IMPORTING
        REQUEST requested_authorizations FOR travel
        RESULT result,
      earlynumbering_create FOR NUMBERING
        IMPORTING entities FOR CREATE travel,
      setStatusToOpen FOR DETERMINE ON MODIFY
        IMPORTING keys FOR travel~setStatusToOpen,
      validateCustomer FOR VALIDATE ON SAVE
        IMPORTING keys FOR travel~validateCustomer.

    METHODS validateDates FOR VALIDATE ON SAVE
      IMPORTING keys FOR travel~validateDates.
*          METHODS deductDiscount FOR MODIFY
*            IMPORTING keys FOR ACTION TRAVEL~deductDiscount RESULT result.
    METHODS deductDiscounts FOR MODIFY
      IMPORTING keys FOR ACTION travel~deductDiscounts RESULT result.
    METHODS copyTravel FOR MODIFY
      IMPORTING keys FOR ACTION travel~copyTravel.
*    METHODS acceptTravel FOR MODIFY
*      IMPORTING keys FOR ACTION travel~acceptTravel RESULT result.
*
*    METHODS rejectTravel FOR MODIFY
*      IMPORTING keys FOR ACTION travel~rejectTravel RESULT result.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR travel RESULT result.

    METHODS deductDiscount FOR MODIFY
      IMPORTING keys FOR ACTION travel~deductDiscount RESULT result.
    METHODS acceptTravel FOR MODIFY
      IMPORTING keys FOR ACTION travel~acceptTravel RESULT result.

    METHODS rejectTravel FOR MODIFY
      IMPORTING keys FOR ACTION travel~rejectTravel RESULT result.
ENDCLASS.

CLASS lhc_zr_rap100_atravmfb001 IMPLEMENTATION.
  METHOD get_global_authorizations.
  ENDMETHOD.
  METHOD earlynumbering_create.

    DATA : entity           TYPE STRUCTURE FOR CREATE zr_rap100_atravmfb001,
           max_travel_id    TYPE /dmo/travel_id,
           " change to abap_false if you get the ABAP Runtime error 'BEHAVIOR_ILLEGAL_STATEMENT'
           use_number_range TYPE abap_bool VALUE abap_false.

    "--Ensure TRAVEL ID is not set yet
    LOOP AT entities INTO entity WHERE travelid IS NOT INITIAL.
      APPEND CORRESPONDING #( entity ) TO mapped-travel.
    ENDLOOP.

    DATA(entities_wo_travelid) = entities.

    DELETE entities_wo_travelid WHERE travelid IS NOT INITIAL.

    IF use_number_range = abap_true.
      "--Get Numbers
      TRY.
          cl_numberrange_runtime=>number_get(
            EXPORTING
*     ignore_buffer     =
              nr_range_nr       = '99'
              object            = '/DMO/TRV_M'
              quantity          = CONV #( lines( entities_wo_travelid ) )
*     subobject         =
*     toyear            =
            IMPORTING
              number            = DATA(number_range_key)
              returncode        = DATA(number_range_return_code)
              returned_quantity = DATA(number_range_returned_quantity)
          ).
* CATCH cx_nr_object_not_found.
        CATCH cx_number_ranges INTO DATA(lx_number_ranges).
          LOOP AT entities_wo_travelid INTO entity.

            APPEND VALUE #( %cid = entity-%cid
                            %key = entity-%key
                            %is_draft = entity-%is_draft
                            %msg = lx_number_ranges ) TO reported-travel.

            APPEND VALUE #( %cid = entity-%cid
                           %key = entity-%key
                           %is_draft = entity-%is_draft
                            ) TO failed-travel.

          ENDLOOP.
          EXIT.
      ENDTRY.
      "--Determine the TravelID  from the Number Range
      max_travel_id = number_range_key - number_range_returned_quantity.
    ELSE.

      SELECT SINGLE FROM zrap100_atravmfb FIELDS MAX( travel_id ) AS travel_id INTO @max_travel_id.

      SELECT SINGLE FROM zrp100_atrv004_d FIELDS MAX( travelid ) AS travel_id INTO @DATA(maxd_travel_id).

      IF maxd_travel_id > max_travel_id.
        max_travel_id = maxd_travel_id.
      ENDIF.




    ENDIF.



    "--Set TRAVEL ID for new Instances w/o ID
    LOOP AT entities_wo_travelid INTO entity.

      max_travel_id += 1.
      entity-TravelId = max_travel_id.

      APPEND VALUE #( %cid = entity-%cid
                      %key = entity-%key
                      %is_draft = entity-%is_draft ) TO mapped-travel.
    ENDLOOP.
  ENDMETHOD.

  METHOD setStatusToOpen.
    "--Read  Travel Instances of Transferred Keys
    READ ENTITIES OF zr_rap100_atravmfb001 IN LOCAL MODE
    ENTITY travel
    FIELDS ( OverallStatus )
    WITH CORRESPONDING #( keys )
    RESULT DATA(travels)
    FAILED DATA(read_failed).

    "--Remove Instances where STATUS ALREADY SET
    DELETE travels WHERE OverallStatus IS NOT INITIAL.
    CHECK travels IS NOT INITIAL.

    "--Set MODIFY Status to OPEN
    MODIFY ENTITIES OF zr_rap100_atravmfb001 IN LOCAL MODE
    ENTITY travel
    UPDATE SET  FIELDS
    WITH VALUE #( FOR travel IN travels ( %tky = travel-%tky
                                          OverallStatus = travel_status-open ) )
    REPORTED DATA(Update_reported).

    reported = CORRESPONDING #( DEEP update_reported ).


  ENDMETHOD.

  METHOD validateCustomer.

    "--READ INSTANCES OF TRAVEL

    READ ENTITIES OF zr_rap100_atravmfb001 IN LOCAL MODE
    ENTITY travel
    FIELDS ( CustomerID )
    WITH CORRESPONDING #( keys )
    RESULT DATA(travels).

    DATA customers TYPE SORTED TABLE OF /dmo/customer WITH UNIQUE KEY customer_id.
    "--Extract DISTINCT NON-INITIAL Customer IDs
    Customers = CORRESPONDING #( travels DISCARDING DUPLICATES MAPPING customer_id = CustomerId EXCEPT * ).

    DELETE customers WHERE customer_id IS INITIAL.

    IF customers IS NOT INITIAL.
      "--Check if CUSTOMER ID EXISTS
      SELECT FROM /dmo/customer  FIELDS customer_id
      FOR ALL ENTRIES IN @customers
      WHERE customer_id = @customers-customer_id
      INTO TABLE @DATA(valid_customers).


    ENDIF.

    "--Raise Message for Non-Existing Customer IDs

    LOOP AT travels INTO DATA(travel).

      APPEND VALUE #(  %tky                 = travel-%tky
                               %state_area          = 'VALIDATE_CUSTOMER'
                             ) TO reported-travel.

      IF travel-CustomerID IS  INITIAL.
        APPEND VALUE #( %tky = travel-%tky ) TO failed-travel.

        APPEND VALUE #( %tky                = travel-%tky
                        %state_area         = 'VALIDATE_CUSTOMER'
                        %msg                = NEW /dmo/cm_flight_messages(
                                                                textid   = /dmo/cm_flight_messages=>enter_customer_id
                                                                severity = if_abap_behv_message=>severity-error )
                        %element-CustomerID = if_abap_behv=>mk-on
                      ) TO reported-travel.
      ELSEIF travel-CustomerID IS NOT INITIAL AND NOT line_exists( valid_customers[ customer_id = travel-CustomerID ] ).
        APPEND VALUE #(  %tky = travel-%tky ) TO failed-travel.

        APPEND VALUE #(  %tky                = travel-%tky
                         %state_area         = 'VALIDATE_CUSTOMER'
                         %msg                = NEW /dmo/cm_flight_messages(
                                                                customer_id = travel-customerid
                                                                textid      = /dmo/cm_flight_messages=>customer_unkown
                                                                severity    = if_abap_behv_message=>severity-error )
                         %element-CustomerID = if_abap_behv=>mk-on
                      ) TO reported-travel.
      ENDIF.

    ENDLOOP.
  ENDMETHOD.

  METHOD validateDates.

    READ ENTITIES OF zr_rap100_atravmfb001 IN LOCAL MODE
    ENTITY travel
    FIELDS ( BeginDate EndDate TravelId )
    WITH CORRESPONDING #( keys )
    RESULT DATA(travels).

    LOOP AT travels INTO DATA(travel).

      APPEND VALUE #( %tky = travel-%tky
                      %state_area = 'VALIDATE_DATES' ) TO reported-travel.

      IF travel-BeginDate IS INITIAL.

        APPEND VALUE #( %tky = travel-%tky  ) TO failed-travel.

        APPEND VALUE #( %tky               = travel-%tky
                        %state_area        = 'VALIDATE_DATES'
                         %msg              = NEW /dmo/cm_flight_messages(
                                                                textid   = /dmo/cm_flight_messages=>enter_begin_date
                                                                severity = if_abap_behv_message=>severity-error )
                      %element-BeginDate = if_abap_behv=>mk-on ) TO reported-travel.


      ENDIF.

      IF travel-BeginDate < cl_abap_context_info=>get_system_date(  )    AND travel-BeginDate IS NOT INITIAL.
        APPEND VALUE #( %tky               = travel-%tky ) TO failed-travel.

        APPEND VALUE #( %tky               = travel-%tky
                        %state_area        = 'VALIDATE_DATES'
                         %msg              = NEW /dmo/cm_flight_messages(
                                                                begin_date = travel-BeginDate
                                                                textid     = /dmo/cm_flight_messages=>begin_date_on_or_bef_sysdate
                                                                severity   = if_abap_behv_message=>severity-error )
                        %element-BeginDate = if_abap_behv=>mk-on ) TO reported-travel.
      ENDIF.
      IF travel-EndDate IS INITIAL.
        APPEND VALUE #( %tky = travel-%tky ) TO failed-travel.

        APPEND VALUE #( %tky               = travel-%tky
                        %state_area        = 'VALIDATE_DATES'
                         %msg                = NEW /dmo/cm_flight_messages(
                                                                textid   = /dmo/cm_flight_messages=>enter_end_date
                                                               severity = if_abap_behv_message=>severity-error )
                        %element-EndDate   = if_abap_behv=>mk-on ) TO reported-travel.
      ENDIF.
      IF travel-EndDate < travel-BeginDate AND travel-BeginDate IS NOT INITIAL
                                        AND travel-EndDate IS NOT INITIAL.
        APPEND VALUE #( %tky = travel-%tky ) TO failed-travel.

        APPEND VALUE #( %tky               = travel-%tky
                        %state_area        = 'VALIDATE_DATES'
                        %msg               = NEW /dmo/cm_flight_messages(
                                                                textid     = /dmo/cm_flight_messages=>begin_date_bef_end_date
                                                                begin_date = travel-BeginDate
                                                                end_date   = travel-EndDate
                                                                severity   = if_abap_behv_message=>severity-error )
                        %element-BeginDate = if_abap_behv=>mk-on
                        %element-EndDate   = if_abap_behv=>mk-on ) TO reported-travel.
      ENDIF.

    ENDLOOP.
  ENDMETHOD.

  METHOD deductDiscount.

  DATA Travels_for_update TYPE TABLE FOR UPDATE ZR_RAP100_ATRAVMFB001.
  DATA(keys_with_valid_discount) = keys.

  READ ENTITIES OF zr_rap100_atravmfb001 IN LOCAL MODE
  ENTITY travel
  FIELDS ( BookingFee )
  WITH CORRESPONDING #( KEYS_WITH_VALID_DISCOUNT )
  RESULT DATA(TRAVELS).

  LOOP AT travels ASSIGNING FIELD-SYMBOL(<TRAVEL>).

  data reduce_fees type p DECIMALS 2.
  reduce_fees = (  (  <travel>-BookingFee * 7 ) / 10 ).
   append value #( %tky = <travel>-%tky
                   bookingfee = reduce_fees
                   %control-bookingfee = if_abap_behv=>mk-on
                   ) to travels_for_update.




  ENDLOOP.
  "--Updating Data with Reduced fees
  MODIFY ENTITIES OF zr_rap100_atravmfb001 IN LOCAL MODE
  ENTITY TRAVEL
  UPDATE FIELDS ( BookingFee  )
  WITH travels_for_update.

  "--Read Changed Data for Reduced Action
  read ENTITIES OF zr_rap100_atravmfb001 IN LOCAL MODE
  ENTITY TRAVEL
  ALL FIELDS WITH CORRESPONDING #( TRAVELS )
  RESULT DATA(travels_with_discount).

  "--Set Action RESULT
  result = value #( FOR TRAVEL IN  travels_with_discount ( %tky = travel-%tky
                                                           %param = travel ) ).

  ENDMETHOD.

  "--Instance Bound Non-Factory Action with Parameter "DeductDiscount"
  "--Deduct Specified Discount from Specified fees

  METHOD deductDiscounts.

    DATA travels_for_update TYPE TABLE FOR UPDATE zr_rap100_atravmfb001.
    DATA(Keys_with_valid_discount) = keys.

    "--Check and Handle Invalid Discount Values
    LOOP AT keys_with_valid_discount ASSIGNING FIELD-SYMBOL(<key_with_valid_discount>)
    WHERE %param-discount_percent IS INITIAL OR %param-discount_percent > 100 OR %param-discount_percent <= 0.

      "--Report Invalid Discount Value Appropriately
      APPEND VALUE #( %tky = <key_with_valid_discount>-%tky  ) TO failed-travel.

      APPEND VALUE #( %tky = <key_with_valid_discount>-%tky
                      %msg = NEW /dmo/cm_flight_messages(
                      textid = /dmo/cm_flight_messages=>discount_invalid
                      severity = if_abap_behv_message=>severity-error

                       )
                       %element-totalPrice = if_abap_behv=>mk-on
                       %op-%action-deductDiscounts = if_abap_behv=>mk-on
                       ) TO reported-travel.
      "--Remove Invalid Discount Value
      DELETE keys_with_valid_discount.

    ENDLOOP.

    CHECK keys_with_valid_discount IS NOT INITIAL.

    "--Read Travel Instance Data only Booking Fees
    READ ENTITIES OF zr_rap100_atravmfb001 IN LOCAL MODE
    ENTITY travel
    FIELDS ( bookingfee )
    WITH CORRESPONDING #( keys_with_valid_discount )
    RESULT DATA(Travels).

    LOOP AT travels ASSIGNING FIELD-SYMBOL(<travel>).

      DATA Percentage TYPE decfloat16.
      DATA(discount_percent) = keys_with_valid_discount[ KEY draft %tky = <travel>-%tky ]-%param-discount_percent.
      percentage = discount_percent / 100.

      DATA(reduced_fees) = <travel>-bookingFee * ( 1 - percentage ).

      APPEND VALUE #( %tky = <travel>-%tky
                      BookingFee = reduced_fees
                      %control-bookingFee = if_abap_behv=>mk-on
                      ) TO travels_for_update.



    ENDLOOP.

    "--Update Data with Reduced Fees

    MODIFY ENTITIES OF zr_rap100_atravmfb001 IN LOCAL MODE
    ENTITY travel
    UPDATE FIELDS ( BookingFee )
    WITH travels_for_update.

    "--Read Changed Data for Action Result
    READ ENTITIES OF zr_rap100_atravmfb001 IN LOCAL MODE
    ENTITY travel
    ALL FIELDS WITH
    CORRESPONDING #( travels )
    RESULT DATA(travel_with_discount).

    "--Set Action Result
    result = VALUE #( FOR travel IN travel_with_discount ( %tky = travel-%tky
                                                             %param = travel    ) ).


  ENDMETHOD.

  METHOD copyTravel.

    DATA : travels TYPE TABLE FOR CREATE zr_rap100_atravmfb001\\travel.

    "--Remove Travel Instances with Initial %cid( i.e. Not Setup by Caller API.

    READ TABLE keys WITH KEY %cid = '' INTO DATA(key_with_initial_cid).
    ASSERT key_with_initial_cid IS INITIAL.

    "--Read Data from TRAVEL Instances to be copied
    READ ENTITIES OF zr_rap100_atravmfb001 IN LOCAL MODE
    ENTITY travel
    ALL FIELDS WITH CORRESPONDING #( keys )
    RESULT DATA(travel_read_result)
    FAILED failed.

    LOOP AT travel_read_result ASSIGNING FIELD-SYMBOL(<travel>).

      "--Fill In Travel Container for creating New TRAVEL INSTANCE
      APPEND VALUE #( %cid = keys[ KEY entity %key = <travel>-%key ]-%cid
                      %is_draft = keys[ KEY entity %key = <travel>-%key ]-%is_draft
                      %data = CORRESPONDING #( <travel> EXCEPT travelid ) )

                      TO travels ASSIGNING FIELD-SYMBOL(<new_travel>).

      "--Adjust the Copied Travel Instance Data
      <new_travel>-BeginDate = cl_abap_context_info=>get_system_date(  ).
      <new_travel>-EndDate = cl_abap_context_info=>get_system_date(  ) + 60.

      <new_travel>-OverallStatus = travel_status-open.






    ENDLOOP.

    MODIFY ENTITIES OF zr_rap100_atravmfb001 IN LOCAL MODE
    ENTITY travel
    CREATE FIELDS ( AgencyId CustomerId BeginDate EndDate BookingFee TotalPrice
                    CurrencyCode OverallStatus Description )
    WITH travels
    MAPPED DATA(mapped_create).

    mapped-travel = mapped_create-travel.


  ENDMETHOD.

*  METHOD acceptTravel.
*
*    MODIFY ENTITIES OF zr_rap100_atravmfb001 IN LOCAL MODE
*    ENTITY travel
*    UPDATE FIELDS ( OverallStatus )
*    WITH VALUE #( FOR key IN keys ( %tky = key-%tky
*                                     OverallStatus = travel_status-accepted
*                                        ) )
*   FAILED failed
*   REPORTED reported.
*
*    "--Read Changed Data for action RESULT
*    READ ENTITIES OF zr_rap100_atravmfb001 IN LOCAL MODE
*    ENTITY travel
*    ALL FIELDS WITH CORRESPONDING #( keys )
* RESULT DATA(Travels).
*
*    "--Set Action Result Parameter
*    result = VALUE #( FOR travel IN travels ( %tky = travel-%tky
*        %param = travel
*     ) )               .
*
*  ENDMETHOD.
*
*  METHOD rejectTravel.
*
*      MODIFY ENTITIES OF zr_rap100_atravmfb001 IN LOCAL MODE
*    ENTITY travel
*    UPDATE FIELDS ( OverallStatus )
*    WITH VALUE #( FOR key IN keys  ( %tky = key-%tky
*                                     OverallStatus = travel_status-rejected
*                                        )  )
*   FAILED failed
*   REPORTED reported.
*
*    "--Read Changed Data for action RESULT
*    READ ENTITIES OF zr_rap100_atravmfb001 IN LOCAL MODE
*    ENTITY travel
*    ALL FIELDS WITH CORRESPONDING #( keys )
* RESULT DATA(Travels).
*
*    "--Set Action Result Parameter
*    result = VALUE #( FOR travel IN travels ( %tky = travel-%tky
*        %param = travel
*     ) )               .
*
*
*  ENDMETHOD.

  METHOD get_instance_features.

    READ ENTITIES OF zr_rap100_atravmfb001 IN LOCAL MODE
    ENTITY travel
    FIELDS ( TravelId OverallStatus )
    WITH CORRESPONDING #( keys )
    RESULT DATA(travels)
    FAILED failed.

    "--Evaluate the conditions , set Operation State and Set Result Parameter
    result = VALUE #( FOR travel IN travels
                     (
                     %tky = travel-%tky
                     %features-%update = COND #( WHEN travel-OverallStatus = travel_status-accepted
                                                 THEN if_abap_behv=>fc-o-disabled ELSE if_abap_behv=>fc-o-enabled )
                     %features-%delete = COND #( WHEN travel-OverallStatus = travel_status-open
                                                 THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
                     %action-Edit = COND #( WHEN travel-OverallStatus = travel_status-accepted
                                          THEN if_abap_behv=>fc-o-disabled ELSE if_abap_behv=>fc-o-enabled )
                     %action-acceptTravel   = COND #( WHEN travel-OverallStatus = travel_status-accepted
                                                            THEN if_abap_behv=>fc-o-disabled ELSE if_abap_behv=>fc-o-enabled   )
                          %action-rejectTravel   = COND #( WHEN travel-OverallStatus = travel_status-rejected
                                                            THEN if_abap_behv=>fc-o-disabled ELSE if_abap_behv=>fc-o-enabled   )
                          %action-deductDiscount = COND #( WHEN travel-OverallStatus = travel_status-open
                                                            THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled   )

                     ) ).

  ENDMETHOD.

  METHOD acceptTravel.

    MODIFY ENTITIES OF zr_rap100_atravmfb001 IN LOCAL MODE
     ENTITY travel
     UPDATE FIELDS ( OverallStatus )
     WITH VALUE #( FOR key IN keys ( %tky = key-%tky
                                      OverallStatus = travel_status-accepted
                                         ) )
    FAILED failed
    REPORTED reported.

    "--Read Changed Data for action RESULT
    READ ENTITIES OF zr_rap100_atravmfb001 IN LOCAL MODE
    ENTITY travel
    ALL FIELDS WITH CORRESPONDING #( keys )
 RESULT DATA(Travels).

    "--Set Action Result Parameter
    result = VALUE #( FOR travel IN travels ( %tky = travel-%tky
        %param = travel
     ) )               .
  ENDMETHOD.

  METHOD rejectTravel.

MODIFY ENTITIES OF zr_rap100_atravmfb001 IN LOCAL MODE
ENTITY travel
UPDATE FIELDS ( OverallStatus )
WITH VALUE #( FOR key IN keys  ( %tky = key-%tky
                                 OverallStatus = travel_status-rejected
                                    )  )
FAILED failed
REPORTED reported.

    "--Read Changed Data for action RESULT
    READ ENTITIES OF zr_rap100_atravmfb001 IN LOCAL MODE
    ENTITY travel
    ALL FIELDS WITH CORRESPONDING #( keys )
 RESULT DATA(Travels).

    "--Set Action Result Parameter
    result = VALUE #( FOR travel IN travels ( %tky = travel-%tky
        %param = travel
     ) )               .


  ENDMETHOD.

ENDCLASS.
