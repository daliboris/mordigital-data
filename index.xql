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

declare variable $idx:default-metalanguage := 'en';

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
            case "genre" return (
                idx:get-genre($header),
                root($root)//dbk:info/dbk:keywordset[@vocab="#genre"]/dbk:keyword,
                root($root)//article-meta/kwd-group[@kwd-group-type="genre"]/kwd
            )
            case "feature" return (
                idx:get-classification($header, 'feature'),
                $root/dbk:info/dbk:keywordset[@vocab="#feature"]/dbk:keyword
            )
            case "form" return (
                idx:get-classification($header, 'form'),
                $root/dbk:info/dbk:keywordset[@vocab="#form"]/dbk:keyword
            )
            case "period" return (
                idx:get-classification($header, 'period'),
                $root/dbk:info/dbk:keywordset[@vocab="#period"]/dbk:keyword
            )
            case "content" return (
                root($root)//body,
                $root/dbk:section
            )
            
            case "sortKey-realisation"                    return if($root/@sortKey) 
                                                            then $root/@sortKey 
                                                          else $root//tei:form[@type=('lemma', 'variant')][1]/tei:orth[1]
            case "head[@type=letter]-content"             return $root/ancestor-or-self::tei:div[@type='letter']/tei:head[@type='letter']
            case "chapter[@xml:id]-value"                 return $root/ancestor-or-self::tei:div[1]/@xml:id
            case "div[@type=letter]/@n-content"           return $root/ancestor-or-self::tei:div[@type='letter']/@n
            case "form[@type=lemma]-content"              return $root//tei:form[@type=('lemma')]/tei:orth
            case "def-content"                            return $root//tei:sense//tei:def
            case "cit[@type=example]-content"             return $root//tei:sense//tei:cit[@type='example']/tei:quote
            case "gram[@type=pos]-realisation"            return idx:get-elements-realisation($root, $root//tei:gram[@type='pos'])
            case "title[@type=main|full]-content"         return string-join((
                                                               $header//tei:msDesc/tei:head, 
                                                               $header//tei:titleStmt/(tei:title[@type = ('main', 'full')]|tei:title)[1]
                                                               ) ! normalize-space(), " - ")
            case "gram[@type=pos]-content"                return idx:get-elements-realisation($root, $root//tei:gram[@type='pos'])
            case "orth[xml:lang]-content"                 return idx:get-object-language($root)
            case "cit|def[xml:lang]-content"              return idx:get-target-language($root)
            case "polysemy"                               return count($root//tei:sense)
            case "gloss-content"                          return $root//tei:gloss
            case "entry[@type]-realisation"               return $root/@type
            case "usg[@type=attitude]-realisation"        return idx:get-elements-realisation($root, $root//tei:usg[@type='attitude'])
            case "usg[@type=domain]-realisation"          return idx:get-elements-realisation($root, $root//tei:usg[@type='domain'])
            case "usg[@type=domain]-hierarchy"            return idx:get-domain-hierarchy($root, $root//tei:usg[@type='domain'])
            case "usg[@type=frequency]-realisation"       return idx:get-elements-realisation($root, $root//tei:usg[@type='frequency'])
            case "usg[@type=geographic]-realisation"      return idx:get-elements-realisation($root, $root//tei:usg[@type='geographic'])
            case "usg[@type=hint]-realisation"            return $root//tei:usg[@type='hint'] | $root/tei:usg[not(@type)]
            case "usg[@type=meaningType]-realisation"     return idx:get-elements-realisation($root, $root//tei:usg[@type='meaningType'])
            case "usg[@type=normativity]-realisation"     return idx:get-elements-realisation($root, $root/tei:usg[@type='normativity'])
            case "usg[@type=socioCultural]-realisation"   return idx:get-elements-realisation($root, $root//tei:usg[@type='socioCultural'])
            case "usg[@type=textType]-realisation"        return idx:get-elements-realisation($root, $root//tei:usg[@type='textType'])
            case "usg[@type=time]-realisation"            return idx:get-elements-realisation($root, $root//tei:usg[@type='time'])
            case "bibl[@type=attestation]-realisation"    return idx:get-attestation-bibl($root) 
            case "bibl[@type=attestation]/author-content" return $root//tei:bibl[@type='attestation']/tei:author
            case "bibl[@type=attestation]/title-content"  return $root//tei:bibl[@type='attestation']/tei:title
            case "metamark[@function]-value"              return $root//tei:metamark/@function
                        
            default return
                ()
};

(:
: Returns genre classicication used by TEI Publisher.
:)
declare function idx:get-genre($header as element()?) {
    for $target in $header//tei:textClass/tei:catRef[@scheme="#genre"]/@target
    let $category := id(substring($target, 2), doc($idx:app-root || "/data/taxonomy.xml"))
    return
        $category/ancestor-or-self::tei:category[parent::tei:category]/tei:catDesc
};

(:
: Returns classicication for the selected category (`$scheme`) used by TEI Publisher.
:)
declare function idx:get-classification($header as element()?, $scheme as xs:string) {
    let $taxonomy := doc($idx:app-root || "/data/taxonomy.xml")
    return 
        if(not(exists($taxonomy))) then () 
    else
        for $target in $header//tei:textClass/tei:catRef[@scheme="#" || $scheme]/@target
        let $category := id(substring($target, 2), $taxonomy)
        return
            $category/ancestor-or-self::tei:category[parent::tei:category]/tei:catDesc
};

(:~
 : Returns the content of the taxonomy defined in the `<tei:catDesc>` element 
 : (i.e. `<tei:term>`  and `<tei:idno>` if available). 
 : Only one `<tei:catDesc>` element is selected: either default (see `$idx:default-metalanguage`)
 : or the first one from the parent `<tei:category>` element.
 : `$targets` attribute can contain `xml:id`s of the `<tei:category>` with or without startin hashtag (#).
:)
declare function idx:get-values-from-taxonomy($root as document-node(), $targets as item()*) {
    for $target in $targets
    let $start := if(starts-with($target, '#')) then 2 else 1
    let $category := id(substring($target, $start), $root)
    let $description := if(exists($category/tei:catDesc[@xml:lang=$idx:default-metalanguage])) 
        then 
            $category/tei:catDesc[@xml:lang=$idx:default-metalanguage] 
        else 
            $category/tei:catDesc[1]
    return
        $description/(tei:idno | tei:term)
};

(:~
 : Returns all taxonomy values from the referenced category and all ancestors.
:)
declare function idx:get-all-values-from-taxonomy($root as document-node(), $targets as item()*) {
    for $target in $targets
    let $start := if(starts-with($target, '#')) then 2 else 1
    let $category := id(substring($target, $start), $root)/ancestor-or-self::tei:category[(parent::tei:category or parent::tei:taxonomy)]
    let $description := if(exists($category/tei:catDesc[@xml:lang=$idx:default-metalanguage])) 
        then 
            $category/tei:catDesc[@xml:lang=$idx:default-metalanguage] 
        else 
            $category/tei:catDesc[1]
    return
        $description/(tei:idno | tei:term)
};

(:~
 : Returns value of the element, value of `@norm` attribute
:)
declare function idx:get-elements-realisation-simple($entry as element(), $items as element()*) {
    if($items) then
        let $values := for $item in $items return ($item/@norm/data(), $item/data())
        return $values
    else
    ()
};

(:~
 : Returns value of the element, value of `@norm` attribute, 
 value of taxonomy assigned to the element using `@ana` attribute.
:)
declare function idx:get-elements-realisation($entry as element(), $items as element()*) {
    if($items) then
        let $values := idx:get-elements-realisation-simple($entry, $items)
        let $taxonomy := idx:get-values-from-taxonomy(root($entry),  $items[@ana]/@ana)
        return ($values, $taxonomy/data())
    else
    ()
};

(:~
 : Returns values of the related terms in the taxonomy
 : assigned to the element using `@ana` attribute.
:)
declare function idx:get-domain-hierarchy($entry as element()?, $targets as element()*) { 
if (empty($entry)) then ()
else
let $root := root($entry)
let $keys := if (empty($targets)) then () 
    else $targets/substring-after(@ana, '#')

return if (empty($keys)) 
            then ()
            else
            idx:get-hierarchical-descriptor($root, $keys)
};

(:~
 : Helper functions for hierarchical facets with several occurrences in a single document of the same vocabulary
 :)
declare function idx:get-hierarchical-descriptor($root as document-node(), $keys as xs:string*) {
  array:for-each (array {$keys}, function($key) {
        let $category := id($key, $root)/ancestor-or-self::tei:category[(parent::tei:category or parent::tei:taxonomy)]
        let $description := if(exists($category/tei:catDesc[@xml:lang=$idx:default-metalanguage])) 
            then 
                $category/tei:catDesc[@xml:lang=$idx:default-metalanguage] 
            else 
                $category/tei:catDesc[1]
        return $description/normalize-space(concat(tei:idno, ' ', tei:term))
    })
};


declare function idx:get-complex-form-type($entry as element()?) {
    idx:get-values-from-taxonomy(root($entry), $entry//tei:entry[@type='complexForm'][contains(@ana, 'complexFormType')]/@ana)
    (:
    for $target in $entry//tei:ref[@type='entry'][contains(@ana, 'complexFormType')]/@ana
        let $category := id(substring($target, 2), root($entry))
    return $category/ancestor-or-self::tei:category[(parent::tei:category or parent::tei:taxonomy)]/tei:catDesc/(tei:idno | tei:term) 
    :)
};


(: 
    Returns distinct values of the `@xml:lang` attribute of all `tei:orth` elements in the entry.
:)
declare function idx:get-object-language($entry as element()?) {
    let $items := idx:get-items-language($entry//tei:form[@type=('lemma', 'variant')]/tei:orth)
    return distinct-values($items)
};

(: 
 : Returns distinct values of the @xml:lang attribute of all `tei:def` 
 : and `tei:cit[@type='translation']` elements in the entry.
:)
declare function idx:get-target-language($entry as element()?) {
    let $items := idx:get-items-language($entry//(tei:def | tei:cit[@type='translation']))
    return distinct-values($items)
};

(:
 : Returns all `@xml:lang` values defined on the elements
 : or first ancestor `@xml:lang` attribute
 : if the `@xml:lang` attribute on the element is missing.
:)
declare function  idx:get-items-language($items as element()*) {
    let $values := for $item in $items 
    return if($item[@xml:lang]) 
                then 
                    $item/@xml:lang 
                else 
                    $item/ancestor::*[@xml:lang][1]/@xml:lang
     return $values
};

(: 
    Returns the content of tei:title, or tei:author element or concatenation of them
    if both of them are available.
:)
declare function idx:get-attestation-bibl($entry as element()?) {
  for $bibl in $entry//tei:bibl[@type='attestation'] 
  return
   if(not($bibl/tei:author)) then $bibl/tei:title
   else if(not($bibl/tei:title)) then $bibl/tei:author
   else if (count($bibl/tei:author) eq 1 and count($bibl/tei:title) eq 1) then
    concat($bibl/tei:author, ', ', $bibl/tei:title)
   else ($bibl/tei:author, $bibl/tei:title)
  (:
    else 
     (:head(($bibl/tei:author, $bibl/tei:title)) => data():)
     ($bibl/tei:author, $bibl/tei:title)[1] => data()
    :)
};