xquery version "3.0";

(: import module namespace pmu="http://www.tei-c.org/tei-simple/xquery/util"; :)
(: import module namespace pmc="http://www.tei-c.org/tei-simple/xquery/config"; :)
(: import module namespace odd="http://www.tei-c.org/tei-simple/odd2odd"; :)
(: import module namespace config="http://www.tei-c.org/tei-simple/config" at "modules/config.xqm"; :)
(: import module namespace tpu="http://www.tei-c.org/tei-publisher/util" at "util.xql"; :)
declare namespace config="http://www.tei-c.org/tei-simple/config";

declare namespace repo="http://exist-db.org/xquery/repo";

(: The following external variables are set by the repo:deploy function :)

(: file path pointing to the exist installation directory :)
declare variable $home external;
(: path to the directory containing the unpacked .xar package :)
declare variable $dir external;
(: the target collection into which the app is deployed :)
declare variable $target external;


declare variable $config:app-root :=
    let $rawPath := system:get-module-load-path()
    let $modulePath :=
        (: strip the xmldb: part :)
        if (starts-with($rawPath, "xmldb:exist://")) then
            if (starts-with($rawPath, "xmldb:exist://embedded-eXist-server")) then
                substring($rawPath, 36)
            else
                substring($rawPath, 15)
        else
            $rawPath
    return
        $modulePath
        (: substring-before($modulePath, "/modules") :)
;

declare variable $config:data-root := $config:app-root || "/data";


declare variable $repoxml :=
    let $uri := doc($target || "/expath-pkg.xml")/*/@name
    let $repo := util:binary-to-string(repo:get-resource($uri, "repo.xml"))
    return
        parse-xml($repo)
;

declare function local:mkcol-recursive($collection, $components) {
    if (exists($components)) then
        let $newColl := concat($collection, "/", $components[1])
        return (
            if (not(xmldb:collection-available($collection || "/" || $components[1]))) then
                let $created := xmldb:create-collection($collection, $components[1])
                return (
                    sm:chown(xs:anyURI($created), $repoxml//repo:permissions/@user),
                    sm:chgrp(xs:anyURI($created), $repoxml//repo:permissions/@group),
                    sm:chmod(xs:anyURI($created), replace($repoxml//repo:permissions/@mode, "(..).(..).(..).", "$1x$2x$3x"))
                )
            else
                (),
            local:mkcol-recursive($newColl, subsequence($components, 2))
        )
    else
        ()
};

(: Helper function to recursively create a collection hierarchy. :)
declare function local:mkcol($collection, $path) {
    local:mkcol-recursive($collection, tokenize($path, "/"))
};

declare function local:create-data-collection() {
    if (xmldb:collection-available($config:data-root)) then
        ()
    else if (starts-with($config:data-root, $target)) then
        local:mkcol($target, substring-after($config:data-root, $target || "/"))
    else
        ()
};



(: API needs dba rights for LaTeX :)

local:create-data-collection(),
local:mkcol($config:data-root, "/dictionaries"),
local:mkcol($config:data-root, "/about")

(:
sm:chgrp(xs:anyURI($target || "/modules/lib/api-dba.xql"), "dba"),
sm:chmod(xs:anyURI($target || "/modules/lib/api-dba.xql"), "rwxr-Sr-x"),

local:mkcol($target, "transform"),
local:generate-code($target),
local:create-data-collection(),
let $pmuConfig := pmc:generate-pm-config(($config:odd-available, $config:odd-internal), $config:default-odd, $config:odd-root)
return
    xmldb:store($config:app-root || "/modules", "pm-config.xql", $pmuConfig, "application/xquery")
:)