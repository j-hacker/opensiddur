xquery version "3.0";
(:~ effect schema upgrades 
 : 
 : Open Siddur Project
 : Copyright 2014 Efraim Feinstein
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
module namespace upg="http://jewishliturgy.org/modules/upgrade";

import module namespace data="http://jewishliturgy.org/modules/data"
    at "data.xqm";
import module namespace crest="http://jewishliturgy.org/modules/common-rest"
    at "common-rest.xqm";
import module namespace src="http://jewishliturgy.org/api/data/sources"
    at "../api/data/sources.xqm";
import module namespace tran="http://jewishliturgy.org/api/transliteration"
    at "../api/data/transliteration.xqm";

declare namespace tei="http://www.tei-c.org/ns/1.0";

(:~ schema changes for 0.7.5
 : * tei:availability/@status was removed
 : * tei:sourceDesc/tei:link becomes tei:bibl/tei:ptr; 
 :)
declare function upg:schema-changes-0-7-5(
    ) {
    update delete collection("/db/data")//tei:availability/@status,
    for $sourceDescLink in collection("/db/data")//tei:sourceDesc/tei:link
    return
        update replace $sourceDescLink with 
            element tei:bibl {
                element tei:ptr {
                    attribute type { "bibl" },
                    attribute target { tokenize($sourceDescLink/@target, '\s+')[2] } 
                },
                element tei:ptr {
                    attribute type { "bibl-content" },
                    attribute target { tokenize($sourceDescLink/@target, '\s+')[1] } 
                }
            }
};

(: not strictly speaking a schema change:
 : any resource in /db/data with a name containing ,;= will be renamed.
 : NOTE: if we expected any links to such files, the links would also have to be changed.
 : Fortunately, we do not expect external links. If they are found, they will have to 
 : be manually corrected.
 :)
declare function upg:schema-changes-0-8-0() {
    for $document in collection("/db/data")
    let $collection := util:collection-name($document)
    let $resource := util:document-name($document)
    let $resource-number := 
        let $n := tokenize($resource, '-')[last()]
        where matches($n, "\d+\.xml")
        return $n
    let $title := 
        if (starts-with($collection, "/db/data/sources"))
        then src:title-function($document)
        else if (starts-with($collection, "/db/data/transliteration"))
        then tran:title-function($document)
        else crest:tei-title-function($document)
    let $new-name := 
        string-join((
            encode-for-uri(replace(replace(normalize-space($title), "\p{M}", ""), "[,;:$=@]+", "-")),
            $resource-number), "-") || ".xml"
    where not($resource = $new-name)
    return (
        util:log-system-out("Renaming: " || $collection || "/" || $resource || " -> " || $new-name),
        xmldb:rename($collection, $resource, $new-name)
    )
};

declare function upg:all-schema-changes() {
    upg:schema-changes-0-7-5(),
    upg:schema-changes-0-8-0()
};
