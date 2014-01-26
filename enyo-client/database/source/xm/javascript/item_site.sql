/* Delete previously misnamed record */
delete from xt.js where js_context='xtuple' and js_type = 'item_site';

select xt.install_js('XM','ItemSite','xtuple', $$
  /* Copyright (c) 1999-2014 by OpenMFG LLC, d/b/a xTuple. 
     See www.xm.ple.com/CPAL for the full text of the software license. */

(function () {

  if (!XM.ItemSite) { XM.ItemSite = {}; }

  XM.ItemSite.isDispatchable = true;

  /**
    Return the current cost for a particular item site.
  */
  XM.ItemSite.cost = function (itemsiteId) {
    if (!XT.Data.checkPrivilege('ViewCosts')) { return null };
    return plv8.execute('select itemcost(itemsite_id) as cost from itemsite where obj_uuid = $1;', [itemsiteId])[0].cost;
  };

  /** @private */
  var _fetch = function (recordType, query) {
    query = query || {};
    var namespace = recordType.beforeDot(),
      type = recordType.afterDot(),
      customerId = null,
      shiptoId,
      effectiveDate = new Date(),
      vendorId = null,
      limit = query.rowLimit ? 'limit ' + Number(query.rowLimit) : '',
      offset = query.rowOffset ? 'offset ' + Number(query.rowOffset) : '',
      clause,
      spliceIndex,
      twoIfSplice = 0,
      aliasInjection,
      customerNumber,
      itemNumber,
      sql = 'select * from %1$I.%2$I where id in ' +
            '(select id ' +
            ' from %1$I.%2$I ' +
            ' where {conditions} ';

    /* Handle special parameters */
    if (query.parameters) {
      query.parameters = query.parameters.filter(function (param) {
        var result = false;
        switch (param.attribute)
        {
        case "customer":
          customerNumber = param.value;
          customerId = XT.Data.getId(XT.Orm.fetch('XM', 'CustomerProspectRelation'), param.value);
          break;
        case "shipto":
          shiptoId = XT.Data.getId(XT.Orm.fetch('XM', 'CustomerShipto'), param.value);
          break;
        case "effectiveDate":
          effectiveDate = param.value;
          break;
        case "vendor":
          vendorId = XT.Data.getId(XT.Orm.fetch('XM', 'VendorRelation'), param.value);
          break;
        default:
          result = true;
        }
        return result;
      })
    }

    clause = XT.Data.buildClause(namespace, type, query.parameters, query.orderBy);

    /* If customer passed, restrict results to item sites allowed to be sold to that customer */
    if (customerId) {
      sql += ' and (item).id in (' +
             'select item_id from item where item_sold and not item_exclusive ' +
             'union ' +
             'select item_id from xt.custitem where cust_id=${p3} ' +
             '  and ${p5}::date between effective and (expires - 1) ';

      if (shiptoId) {
        sql += 'union ' +
               'select item_id from xt.shiptoitem where shipto_id=${p4}::integer ' +
               '  and ${p5}::date between effective and (expires - 1) ';
      }

      sql += ") ";
    }

    /* If vendor passed, and vendor can only supply against defined item sources, then restrict results */
    if (vendorId) {
      sql +=  ' and (item).id in (' +
              '  select itemsrc_item_id ' +
              '  from itemsrc ' +
              '  where itemsrc_active ' +
              '    and itemsrc_vend_id=' + vendorId + ')';
    }

    sql = XT.format(sql + '{orderBy} %3$s %4$s) {orderBy}',
                    [namespace.decamelize(), type.decamelize(), limit, offset]);

    /* Crazily splice in the option of querying by alias in the middle of the item number part of the WHERE.
       In the future conditions should be able to generate this sort of code itself with the
       proposed aliases*number format. Once that's ready, take this ugly code out. */

    spliceIndex = clause.conditions.indexOf('or (item).barcode');
    if (spliceIndex >= 0) {
      twoIfSplice = 2;
      aliasInjection = " or (item).number in (" +
        "select item_number from item " +
        "inner join itemalias on item_id = itemalias_item_id " +
        "left join crmacct on itemalias_crmacct_id = crmacct_id " +
        "where itemalias_number ~^ ${p1} " +
        "and (crmacct_number is null or crmacct_number = ${p2}) " +
        ") ";
      clause.conditions = clause.conditions.substring(0, spliceIndex) +
        aliasInjection + clause.conditions.substring(spliceIndex);

      itemNumber = query.parameters.filter(function (param) {
        return param.attribute && param.attribute.length && param.attribute.indexOf("item.number") >= 0;
      })[0].value;
    }

    /* Query the model */
    sql = sql.replace('{conditions}', clause.conditions)
             .replace(/{orderBy}/g, clause.orderBy)
             .replace('{limit}', limit)
             .replace('{offset}', offset)
             .replace('{p1}', clause.parameters.length + 1)
             .replace('{p2}', clause.parameters.length + 2)
             .replace(/{p3}/g, clause.parameters.length + 1 + twoIfSplice)
             .replace(/{p4}/g, clause.parameters.length + 2 + twoIfSplice)
             .replace(/{p5}/g, clause.parameters.length + 3 + twoIfSplice);

    if (spliceIndex >= 0) {
      clause.parameters = clause.parameters.concat([itemNumber, customerNumber]);
    }
    if (customerId) {
      clause.parameters = clause.parameters.concat([customerId, shiptoId, effectiveDate]);
    }
    if (DEBUG) {
      plv8.elog(NOTICE, 'sql = ', sql.substr(0,500));
      plv8.elog(NOTICE, 'sql = ', sql.substr(501, 1000));
      plv8.elog(NOTICE, 'parameters = ', clause.parameters);
    }
    return plv8.execute(sql, clause.parameters);
  };

  if (!XM.ItemSiteListItem) { XM.ItemSiteListItem = {}; }

  XM.ItemSiteListItem.isDispatchable = true;

  /**
    Returns item site list items using usual query means with additional special support for:
      * Attributes `customer`,`shipto`, and `effectiveDate` for exclusive item rules.
      * Attribute `vendor` to filter on only items with associated item sources.
      * Cross check on `alias` and `barcode` attributes for item numbers.

    @param {String} Record type. Must have `itemsite` or related view as its orm source table.
    @param {Object} Additional query filter (Optional)
    @returns {Array}
  */
  XM.ItemSiteListItem.fetch = function (query) {
    return _fetch("XM.ItemSiteListItem", query);
  };

  if (!XM.ItemSiteRelation) { XM.ItemSiteRelation = {}; }

  XM.ItemSiteRelation.isDispatchable = true;

  /**
    Returns item site relatinos using usual query means with additional special support for:
      * Attributes `customer`,`shipto`, and `effectiveDate` for exclusive item rules.
      * Attribute `vendor` to filter on only items with associated item sources.
      * Cross check on `alias` and `barcode` attributes for item numbers.

    @param {String} Record type. Must have `itemsite` or related view as its orm source table.
    @param {Object} Additional query filter (Optional)
    @returns {Array}
  */
  XM.ItemSiteRelation.fetch = function (query) {
    return _fetch("XM.ItemSiteRelation", query);
  };

}());

$$ );

