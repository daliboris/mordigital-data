xquery version "3.1";

module namespace upld="https://eldi.soc.cas.cz/api/upload";


import module namespace roaster="http://e-editiones.org/roaster";
import module namespace unzip="http://joewiz.org/ns/xquery/unzip" at "unzip.xql";
import module namespace config = "http://www.tei-c.org/tei-simple/config" at "config.xqm";
import module namespace idx = "http://teilex0/ns/xquery/index" at "report.xql";
import module namespace console="http://exist-db.org/xquery/console";

declare default collation "?lang=pt";


declare namespace errors = "http://e-editiones.org/roaster/errors";
declare namespace map = "http://www.w3.org/2005/xpath-functions/map";
declare namespace tei = "http://www.tei-c.org/ns/1.0";
declare namespace query="http://www.tei-c.org/tei-simple/query";

declare variable $upld:NOT_FOUND := xs:QName("errors:NOT_FOUND_404");

declare variable $upld:channel := "upload";

declare option exist:serialize "method=xml media-type=application/xml";

(: collections (under main data collection) that can't be deleted :)
declare variable $upld:main-collections := 
    ("dictionaries", "about", "feedback", "metadata", "volumes");

declare variable $upld:QUERY_OPTIONS := map {
    "leading-wildcard": "yes",
    "filter-rewrite": "yes"
};


declare function upld:upload($request as map(*)) {
    let $start-time as xs:time := util:system-time()
    let $root := upld:get-collection($request)
    return
    try {
        let $name := request:get-uploaded-file-name("file")
        let $data := request:get-uploaded-file-data("file")
        let $upload-result := upld:upload($root, $name, $data)
        let $end-time as xs:time := util:system-time()
    (: let $log := console:log($upld:channel, "$name: " || $name) :)
    return
        (: roaster:response(201, map { 
                "uploaded": $upload:download-path || $file-name }) :)
        (: array { upld:upload($request?parameters?collection, $name, $data) } :)
        roaster:response(201,
        <result file-name="{$name}" start="{$start-time}" end="{$end-time}" duration="{seconds-from-duration($end-time - $start-time)}s">
            {$upload-result}
        </result>
        )
    }
    catch * {
        let $end-time as xs:time := util:system-time()
        (: roaster:response(400, map { "error": $err:description })         :)
        return
        roaster:response(400, <error start="{$start-time}" end="{$end-time}" duration="{seconds-from-duration($end-time - $start-time)}s">{ $err:description }</error>)
    }
        
};

declare %private function upld:upload($root, $paths, $payloads) {
    let $collectionPath := if(starts-with($root, 'db/system/config' || $config:data-root)) then "/" || $root else $config:data-root || "/" || $root
    let $result := for-each-pair($paths, $payloads, function($path, $data) {
        let $paths :=
            let $log := console:log($upld:channel, "$collectionPath: " || $collectionPath)
            return
                if (xmldb:collection-available($collectionPath)) then
                
                    if (ends-with($path, ".zip")) then
                        let $stored := xmldb:store($collectionPath, xmldb:encode($path), $data)
                        (: let $log := console:log($upld:channel, "$stored: " || $stored) :)
                        let $unzip := unzip:unzip($stored, true())
                        (: let $log := console:log($upld:channel, "$unzip: " || string-join($unzip//entry/@path, '; ')) :)
                        (: return $unzip//entry/@path :)
                        return $unzip
                    else if (ends-with($path, ".xml") or ends-with($path, ".xconf")) then
                        let $stored := xmldb:store($collectionPath, xmldb:encode($path), $data)
                        return <entries target-collection="{$collectionPath}" count-stored="{if($stored) then 1 else 0}" count-unable-to-store="{if($stored) then 0 else 1}" deleted="false">
                            <entry path="{$collectionPath}" file="{$path}" />
                         </entries>
                    else
                    ()
                else
                    error($upld:NOT_FOUND, "Collection not found: " || $collectionPath)
        return
            $paths
            (:
            for $path in $paths 
                let $size := xmldb:size($collectionPath, $path)
                let $log := console:log($upld:channel, "$size: " || $path || " = " || $size)
            return
                map {
                    "name": $path,
                    "path": substring-after($path, $config:data-root || "/" || $root),
                    "type": xmldb:get-mime-type($path),
                    "size": xmldb:size($collectionPath, $path)
                }
                :)
    })
    return $result
};

declare function upld:clean($request as map(*)) {
    try {
        let $name := upld:get-collection($request)
        let $main-collection := tokenize($name, "/")[last()] => lower-case()
        let $collectionPath := $config:data-root || "/" || $name
        return if($main-collection = $upld:main-collections) then
            roaster:response(400,
            <result>{concat("Cannot delete main collection '", $main-collection, "'.")}</result>
            )
        else if($collectionPath = $config:data-root || "/") then
            roaster:response(400,
            <result>{concat("Cannot delete main collection '", $collectionPath, "'.")}</result>
            )
        else
            
            let $result := xmldb:remove($collectionPath)
            return roaster:response(200,
                <result>Collection {$name} deleted.</result>)

    }
    catch * {
        (: roaster:response(400, map { "error": $err:description })         :)
        roaster:response(400, <error>{ $err:description }</error>)
    }

};

declare function upld:report($request as map(*)) { 
    let $name := upld:get-collection($request)
    let $count := $request?parameters?count
    (: return idx:get-collection-statistics() :)
    return idx:get-index-statistics($count)
};

declare %private function upld:get-collection($request as map(*)) {
    let $collection := xmldb:decode-uri($request?parameters?collection)
    let $collection := if(ends-with($config:data-root, "/" || $collection))
        then "" 
        else if(starts-with($collection, 'data/')) 
            then substring-after($collection, 'data/')
            else $collection
    return $collection
};
