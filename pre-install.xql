xquery version "3.1";

import module namespace xdb="http://exist-db.org/xquery/xmldb";

(: The following external variables are set by the repo:deploy function :)

(: file path pointing to the exist installation directory :)
declare variable $home external;
(: path to the directory containing the unpacked .xar package :)
declare variable $dir external;
(: the target collection into which the app is deployed :)
declare variable $target external;

declare function local:mkcol-recursive($collection, $components) {
    if (exists($components)) then
        let $newColl := concat($collection, "/", $components[1])
        return (
            xdb:create-collection($collection, $components[1]),
            local:mkcol-recursive($newColl, subsequence($components, 2))
        )
    else
        ()
};

(: Helper function to recursively create a collection hierarchy. :)
declare function local:mkcol($collection, $path) {
    local:mkcol-recursive($collection, tokenize($path, "/")[. != ''])
};

local:mkcol("/db/system/config",  $target),
xdb:store-files-from-pattern("/db/system/config" || $target, $dir, "**/*.xconf", "text/xml", true())
(: store the main collection configuration :)
(:)
local:mkcol("/db/system/config",  $target),
local:mkcol($target, "data/dictionaries"),
local:mkcol($target, "data/about"),
xdb:store-files-from-pattern("/db/system/config" || $target, $dir, "**/*.xconf", "text/xml", true())
:)
(:, :)
(: store the dictionaries collection configuration :)
(: local:mkcol("/db/system/config", concat($target, "/data/dictionaries")), :)
(: xdb:store-files-from-pattern(concat("/db/system/config", $target, "/data/dictionaries"), concat($dir, "/data/dictionaries"), "*.xconf"), :)
(: store the about collection configuration :)
(: local:mkcol("/db/system/config", concat($target, "/data/about")), :)
(: xdb:store-files-from-pattern(concat("/db/system/config", $target, "/data/about"), concat($dir, "/data/about"), "*.xconf") :)