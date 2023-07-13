xquery version "3.1";

module namespace idx="http://teipublisher.com/index";

declare namespace array = "http://www.w3.org/2005/xpath-functions/array";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace dbk="http://docbook.org/ns/docbook";

declare variable $idx:app-root :=
    let $rawPath := system:get-module-load-path()
    return
        (: strip the xmldb: part :)
        if (starts-with($rawPath, "xmldb:exist://")) then
            if (starts-with($rawPath, "xmldb:exist://embedded-eXist-server")) then
                substring($rawPath, 36)
            else
                substring($rawPath, 15)
        else
            $rawPath
    ;

(:~
 : Helper function called from collection.xconf to create index fields and facets.
 : This module needs to be loaded before collection.xconf starts indexing documents
 : and therefore should reside in the root of the app.
 :)
declare function idx:get-metadata($root as element(), $field as xs:string) {
    let $header := $root/tei:teiHeader
    return
        switch ($field)
            case "title" return
                string-join((
                    $header//tei:msDesc/tei:head, $header//tei:titleStmt/tei:title[@type = 'main'],
                    $header//tei:titleStmt/tei:title,
                    $root/dbk:info/dbk:title
                ), " - ")
            case "author" return (
                $header//tei:correspDesc/tei:correspAction/tei:persName,
                $header//tei:titleStmt/tei:author,
                $root/dbk:info/dbk:author
            )
            case "language" return
                head((
                    $header//tei:langUsage/tei:language[@role='objectLanguage']/@ident,
                    $root/@xml:lang,
                    $header/@xml:lang
                ))
            case "date" return head((
                $header//tei:correspDesc/tei:correspAction/tei:date/@when,
                $header//tei:sourceDesc/(tei:bibl|tei:biblFull)/tei:publicationStmt/tei:date,
                $header//tei:sourceDesc/(tei:bibl|tei:biblFull)/tei:date/@when,
                $header//tei:fileDesc/tei:editionStmt/tei:edition/tei:date,
                $header//tei:publicationStmt/tei:date
            ))
            
            
            case "sortKey-realisation"                    return if($root/@sortKey) 
                                                            then $root/@sortKey 
                                                          else $root//tei:form[@type=('lemma', 'variant')][1]/tei:orth[1]
            case "head[@type=letter]-content"             return $root/ancestor-or-self::tei:div[@type='letter']/tei:head[@type='letter']
            case "chapter[@xml:id]-value"                 return $root/ancestor-or-self::tei:div[1]/@xml:id
            case "div[@type=letter]/@n-content"           return $root/ancestor-or-self::tei:div[@type='letter']/@n
            case "form[@type=lemma]-content"              return $root//tei:form[@type=('lemma')]/tei:orth
            case "def-content"                            return $root//tei:sense//tei:def
            case "cit[@type=example]-content"             return $root//tei:sense//tei:cit[@type='example']/tei:quote
            case "gram[@type=pos]-realisation"            return idx:get-pos($root)
            case "title[@type=main]-content"              return string-join((
                                                               $header//tei:msDesc/tei:head, $header//tei:titleStmt/tei:title[@type = 'main'],
                                                               $header//tei:titleStmt/tei:title), " - ")
            case "gram[@type=pos]-content"                return idx:get-pos($root)
            case "orth[xml:lang]-content"                 return idx:get-object-language($root)
            case "polysemy"                               return count($root//tei:sense)
            case "gloss-content"                          return $root//tei:gloss
            case "entry[@type]-realisation"               return $root/@type
            case "usg[@type=attitude]-realisation"        return $root//tei:usg[@type='attitude']
            case "usg[@type=domain]-realisation"          return $root//tei:usg[@type='domain']
            case "usg[@type=frequency]-realisation"       return $root//tei:usg[@type='frequency']
            case "usg[@type=geographic]-realisation"      return $root//tei:usg[@type='geographic']
            case "usg[@type=hint]-realisation"            return $root//tei:usg[@type='hint'] | $root/tei:usg[not(@type)]
            case "usg[@type=meaningType]-realisation"     return $root//tei:usg[@type='meaningType']
            case "usg[@type=normativity]-realisation"     return $root/tei:usg[@type='normativity']
            case "usg[@type=socioCultural]-realisation"   return $root//tei:usg[@type='socioCultural']
            case "usg[@type=textType]-realisation"        return $root//tei:usg[@type='textType']
            case "usg[@type=time]-realisation"            return $root//tei:usg[@type='time']
            case "bibl[@type=attestation]-realisation"    return idx:get-attestation-bibl($root) 
            case "bibl[@type=attestation]/author-content" return $root//tei:bibl[@type='attestation']/tei:author
            case "bibl[@type=attestation]/title-content"  return $root//tei:bibl[@type='attestation']/tei:title
            case "metamark[@function]-value"              return $root//tei:metamark/@function
                        
            default return
                ()
};
declare function idx:get-domain-hierarchy($entry as element()?) { 
if (empty($entry)) then ()
else
let $root := root($entry)
let $targets := $entry//tei:usg[@type='domain']
let $ids := if (empty($targets)) then () 
    else $targets/substring-after(@ana, '#')

return if (empty($ids)) 
            then ()
            else
            idx:get-hierarchical-descriptor($ids, $root)
};

(:~
 : Helper functions for hierarchical facets with several occurrences in a single document of the same vocabulary
 :)
declare function idx:get-hierarchical-descriptor($keys as xs:string*, $root as item()) {
  array:for-each (array {$keys}, function($key) {
        id($key,$root)
        /ancestor-or-self::tei:category/tei:catDesc[@xml:lang='en']/concat(tei:idno, ' ', tei:term)
    })
};

declare function idx:get-domain($entry as element()?) {
    $entry//tei:usg[@type='domain']
};


declare function idx:get-attestation-bibl($entry as element()?) {
  for $bibl in $entry//tei:bibl[@type='attestation'] 
  return
   if(not($bibl/tei:author)) then $bibl/tei:title
   else if(not($bibl/tei:title)) then $bibl/tei:author
   else concat($bibl/tei:author, ', ', $bibl/tei:title)
  (:
   if(empty($bibl/tei:author)) then $bibl/tei:title
   else if(empty($bibl/tei:title)) then $bibl/tei:author
   else concat($bibl/tei:author, ', ', $bibl/tei:title)
   :)
(:  return concat($bibl/tei:author, ', ', $bibl/tei:title):)
  (:
    if(exists($bibl/tei:author) and exists($bibl/tei:title)) then 
     concat($bibl/tei:author, ', ', $bibl/tei:title) 
    else 
     (:head(($bibl/tei:author, $bibl/tei:title)) => data():)
     ($bibl/tei:author, $bibl/tei:title)[1] => data()
    :)
};

declare function idx:get-complex-form-type($entry as element()?) {
    idx:get-values-from-terminology($entry, $entry//tei:entry[@type='complexForm'][contains(@ana, 'complexFormType')]/@ana)
    (:
    for $target in $entry//tei:ref[@type='entry'][contains(@ana, 'complexFormType')]/@ana
        let $category := id(substring($target, 2), root($entry))
    return $category/ancestor-or-self::tei:category[(parent::tei:category or parent::tei:taxonomy)]/tei:catDesc/(tei:idno | tei:term) 
    :)
};


declare function idx:get-style($entry as element()?) {
    idx:get-values-from-terminology($entry, $entry//tei:usg[@type='textType']/@ana)
    (:
    for $target in $entry//tei:usg[@type='textType']/@ana
        let $category := id(substring($target, 2), root($entry))
    return $category/ancestor-or-self::tei:category[(parent::tei:category or parent::tei:taxonomy)]/tei:catDesc/(tei:idno | tei:term)
    :)
};

declare function idx:get-pos($entry as element()?) {
  for $item in $entry//tei:gram[@type='pos'] return ($item/@norm/data(), $item/data())
(:    idx:get-values-from-terminology($entry, $entry//tei:gram/@ana):)
    (:
    let $category := id(substring($target, 2), root($entry))
    return
        $category/ancestor-or-self::tei:category[(parent::tei:category or parent::tei:taxonomy)]/tei:catDesc/(tei:idno | tei:term)
    :)
};

declare function idx:get-values-from-terminology($entry as element()?, $targets as item()*) {
    for $target in $targets
    let $category := id(substring($target, 2), root($entry))
    return
        $category/ancestor-or-self::tei:category[(parent::tei:category or parent::tei:taxonomy)]/tei:catDesc/(tei:idno | tei:term)
};


declare function idx:get-object-language($entry as element()?) {
    for $target in $entry//tei:form[@type=('lemma', 'variant')]/tei:orth[@xml:lang]
    let $category := $target/@xml:lang
    return
        $category
};

declare function idx:get-target-language($entry as element()?) {
    for $target in $entry//(tei:def | tei:cit[@type='translation'])
    let $category := $target/@xml:lang
    return
        $category
};