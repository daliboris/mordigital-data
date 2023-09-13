xquery version "3.1" encoding "utf-8";

declare namespace idx = "http://teilex0/ns/xquery/index"; 
declare namespace cc="http://exist-db.org/collection-config/1.0";
declare namespace tei="http://www.tei-c.org/ns/1.0";

declare variable $idx:collection external := "/db/apps/mordigital-data/data/dictionaries";
declare variable $idx:max-items external := 20; 

declare function idx:get-collection-statistics() 
{ 
 let $files := uri-collection($idx:collection)
 return
 <collection path="{$idx:collection}">
 {for $file in $files return
  <file name="{$file}" />
 }
 </collection>
};

declare function idx:get-nodes-statistics() {
 let $entries := collection($idx:collection)//tei:entry
 let $divs := collection($idx:collection)//tei:div
 return
 <nodes path="{$idx:collection}">
 {
  <node name="div" count="{count($divs)}" />,
  <node name="entry" count="{count($entries)}" />
 }
 </nodes>
};

declare function idx:get-fields-statistics($fields as element(cc:field)*) 
{ 
 let $query-start-time := util:system-time()
 let $result := for $field in $fields return idx:get-field-statistics($field)
 let $query-end-time := util:system-time()
 return $result
};

declare function idx:get-field-statistics($field as element(cc:field)) 
{ 
let $name := $field/@name
let $all-items := collection($idx:collection)//tei:entry[ft:query(., $name || ":(*)", map { "leading-wildcard": "yes", "filter-rewrite": "yes", "fields": ($name) })] ! ft:field(., $name)
let $items := if($idx:max-items le 0) then
    $all-items else $all-items[position() le $idx:max-items]
return <field name="{$name}" count="{count($all-items)}" distinct="{count(distinct-values($all-items))}">{ for $f at $i in $items
        group by $label := $f
        return <item name="{$label}" count="{count($f)}" />
        }</field> 

};

declare function idx:get-facets-statistics($facets as element(cc:facet)*) 
{ 
 let $query-start-time := util:system-time()
 let $result := for $item in $facets return idx:get-facet-statistics($item)
 let $query-end-time := util:system-time()
 return $result
}; 

declare function idx:get-facet-statistics($facet as element(cc:facet)) 
{ 
let $name := $facet/@dimension
let $result := collection($idx:collection)//tei:entry[ft:query(.,"*", map { "leading-wildcard": "yes", "filter-rewrite": "yes" })]
let $all-facets := ft:facets($result, $name, ())
let $facets := if($idx:max-items = 0) then
    $all-facets else ft:facets($result, $name, $idx:max-items) 

return <facet name="{$name}" count="{map:size($all-facets)}">{ 
          map:for-each($facets, function($label, $count) {
            <item name="{$label}" count="{$count}" />
          })}
        </facet> 

};

declare function idx:get-index-statistics () 
{
 let $config := doc("/db/system/config" || $idx:collection || "/" || "collection.xconf")
 
 
 let $fields := $config//cc:text[@qname='tei:entry']/cc:field
 let $facets := $config//cc:text[@qname='tei:entry']/cc:facet

return
 <statistics>{
  idx:get-collection-statistics(),
  idx:get-nodes-statistics(),
  idx:get-fields-statistics($fields),
  idx:get-facets-statistics($facets)
 }
 </statistics>

}; 


idx:get-index-statistics()
