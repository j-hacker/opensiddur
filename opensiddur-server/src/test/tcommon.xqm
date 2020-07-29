xquery version "3.1";

(:~
: Common tests
:
: Copyright 2019 Efraim Feinstein <efraim@opensiddur.org>
: Open Siddur Project
: Licensed under the GNU Lesser General Public License, version 3 or later
:)

module namespace tcommon = "http://jewishliturgy.org/test/tcommon";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
declare namespace html="http://www.w3.org/1999/xhtml";
declare namespace http="http://expath.org/ns/http-client";
declare namespace rest="http://exquery.org/ns/restxq";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

import module namespace deepequality="http://jewishliturgy.org/modules/deepequality"
  at "../modules/deepequality.xqm";
import module namespace data="http://jewishliturgy.org/modules/data"
  at "../modules/data.xqm";
import module namespace format="http://jewishliturgy.org/modules/format"
  at "../modules/format.xqm";
import module namespace magic="http://jewishliturgy.org/magic"
  at "../magic/magic.xqm";
import module namespace ridx="http://jewishliturgy.org/modules/refindex"
  at "../modules/refindex.xqm";
import module namespace user="http://jewishliturgy.org/api/user"
  at "../api/user.xqm";

(:~ test if a given returned index has a discovery API, return an error if it doesn't :)
declare function tcommon:contains-discovery-api(
  $result as item()*
  ) as element()? {
  let $test := $result/self::html:html/html:body/*[@class="apis"]/html:li[@class="api"]/html:a[@class="discovery"]
  where empty($test)
  return <error desc="expected a discovery api, got">{$result}</error>
};

(:~ test if a given returned result contains search results, otherwise, return errors :)
declare function tcommon:contains-search-results(
    $result as item()*
) as element()* {
    if ($result/self::rest:response/output:serialization-parameters/output:method="xhtml")
    then ()
    else <error desc="serialize as XHTML">{$result}</error>,
    if (empty($result//html:head/@profile))
    then ()
    else <error desc="reference to Open Search @profile removed for html5 compliance">{$result}</error>,
    if (count($result//html:meta[@name='startIndex'])=1)
    then ()
    else <error desc="@startIndex is present">{$result}</error>,
    if (count($result//html:meta[@name='endIndex'])=0)
    then ()
    else <error desc="@endIndex has been removed">{$result}</error>,
    if (count($result//html:meta[@name='totalResults'])=1)
    then ()
    else <error desc="@totalResults is present">{$result}</error>,
    if (count($result//html:meta[@name='itemsPerPage'])=1)
    then ()
    else <error desc="@itemsPerPage is present">{$result}</error>
};

(:~ test is a Not Found response :)
declare function tcommon:not-found($result as item()*) as element()? {
    let $test := $result/self::rest:response/http:response/@status = 404
    where empty($test)
    return <error desc="expected not found, got">{$result}</error>
};

(:~ test if result contains a no data response :)
declare function tcommon:no-data($result as item()*) as element()* {
    if ($result/self::rest:response/http:response/@status = 204)
    then ()
    else <error desc="returns status code 204">{$result}</error>,
    if ($result/self::rest:response/output:serialization-parameters/output:method = "text")
    then ()
    else <error desc="serializes as text">{$result}</error>
};

(:~ test if a resource has a created response :)
declare function tcommon:created($result as item()*) as element()* {
    if ($result/self::rest:response/http:response/@status = 201)
    then ()
    else <error desc="returns status code 201">{$result}</error>,
    if (exists($result/self::rest:response/http:response/http:header[@name="Location"][@value]))
    then ()
    else <error desc="returns a Location header">{$result}</error>
};

(:~ test if result contains a forbidden response :)
declare function tcommon:forbidden($result as item()*) as element()* {
    if ($result/self::rest:response/http:response/@status = 403)
    then ()
    else <error desc="returns status code 403">{$result}</error>
};

(:~ test if result contains a bad request response :)
declare function tcommon:bad-request($result as item()*) as element()* {
    if ($result/self::rest:response/http:response/@status = 400)
    then ()
    else <error desc="returns status code 400">{$result}</error>
};

(:~ test if result contains an unauthorized response :)
declare function tcommon:unauthorized($result as item()*) as element()* {
    if ($result/self::rest:response/http:response/@status = 401)
    then ()
    else <error desc="returns status code 401">{$result}</error>
};

(:~ test if an HTML5 serialization command is included :)
declare function tcommon:serialize-as-html5($result as item()*) as element()? {
  let $test := $result/self::rest:response/output:serialization-parameters/output:method="xhtml"
  where empty($test)
  return <error desc="expected serialization as HTML5, got">{$result}</error>
};

(:~ return a minimally "valid" TEI header :)
declare function tcommon:minimal-valid-header(
  $title as xs:string
) as element(tei:teiHeader) {
  <tei:teiHeader>
    <tei:fileDesc>
      <tei:titleStmt>
        <tei:title type="main">{$title}</tei:title>
      </tei:titleStmt>
      <tei:publicationStmt>
        <tei:distributor>
          <tei:ref target="http://opensiddur.org">Open Siddur Project</tei:ref>
        </tei:distributor>
        <tei:availability>
          <tei:licence target="http://www.creativecommons.org/publicdomain/zero/1.0"/>
        </tei:availability>
        <tei:date>2020-01-01</tei:date>
      </tei:publicationStmt>
      <tei:sourceDesc>
        <tei:bibl>
          <tei:ptr type="bibl" target="/data/sources/Born%20Digital"/>
          <tei:ptr type="bibl-content" target="#stream"/>
        </tei:bibl>
      </tei:sourceDesc>
    </tei:fileDesc>
    <tei:revisionDesc>
    </tei:revisionDesc>
  </tei:teiHeader>
};

(:~ set up a number $n of test users named xqtestN :)
declare function tcommon:setup-test-users(
    $n as xs:integer
) {
    for $i in 1 to $n
    let $name := "xqtest" || string($i)
    let $log := util:log-system-out("Setting up user " || $name)
    let $creation :=
        system:as-user("admin", $magic:password, (
            let $create-account := sm:create-account($name, $name, "everyone")
            let $stored :=
                xmldb:store($user:path,
                  concat($name, ".xml"),
                  <j:contributor>
                    <tei:idno>{$name}</tei:idno>
                  </j:contributor>
                )
            let $uri := xs:anyURI($stored)
            let $chmod := sm:chmod($uri, "rw-r--r--")
            let $chown := sm:chown($uri, $name)
            let $chgrp := sm:chgrp($uri, $name)
            return ()
        ))
    return (
        tcommon:wait-for("existence of user " || string($i),
        function () { system:as-user("admin", $magic:password, sm:user-exists($name) ) } )
    )
};

declare function tcommon:wait-for(
    $desc as xs:string,
    $condition as function() as xs:boolean
) {
    if (not($condition()))
    then
        let $log := util:log("info", "Waiting for " || $desc)
        let $wait := util:wait(100)
        return tcommon:wait-for($desc, $condition)
    else ()
};

(:~ remove N test users :)
declare function tcommon:teardown-test-users(
    $n as xs:integer
) {
    for $i in 1 to $n
    return
        system:as-user("xqtest" || string($i), "xqtest" || string($i),
        user:delete("xqtest" || string($i))
        )
};

(:~ set up a resource as if it had been added by API :)
declare function tcommon:setup-resource(
  $resource-name as xs:string,
  $data-type as xs:string,
  $owner as xs:integer,
  $content as item(),
  $subtype as xs:string?,
  $group as xs:string?,
  $permissions as xs:string?
) as xs:string {
  let $resource-path := system:as-user("xqtest" || string($owner), "xqtest" || string($owner),
      let $path := xmldb:store(
      string-join(("/db/data", $data-type, $subtype), "/"), $resource-name || ".xml", $content)
      let $wait := tcommon:wait-for("Storing " || $path, function() { doc-available($path) })
      let $ridx := ridx:reindex(doc($path))
      let $log := util:log("info", "Saved " || $path || " as " || $owner)
      return $path
  )
  let $change-group :=
    if ($group)
    then system:as-user("admin", $magic:password, sm:chgrp(xs:anyURI($resource-path), $group))
    else ()
  let $change-permissions :=
    if ($permissions)
    then system:as-user("admin", $magic:password, sm:chmod(xs:anyURI($resource-path), $permissions))
    else ()
  return $resource-path
};

declare function tcommon:setup-resource(
  $resource-name as xs:string,
  $data-type as xs:string,
  $owner as xs:integer,
  $content as item()
) as xs:string {
    tcommon:setup-resource($resource-name, $data-type, $owner, $content, (), (), ())
};

(:~ remove a test resource :)
declare function tcommon:teardown-resource(
  $resource-name as xs:string,
  $data-type as xs:string,
  $owner as xs:integer
) {
  system:as-user("xqtest" || string($owner), "xqtest" || string($owner),
      let $test-collection := "/db/data/" || $data-type
      let $doc := data:doc($data-type, $resource-name)
      return
        if (exists($doc))
        then
            let $uri := fn:document-uri($doc)
            let $collection := util:collection-name($doc)
            let $res := util:document-name($doc)
            return (
                format:clear-caches($uri),
                ridx:remove($collection, $res),
                xmldb:remove($collection, $res)
            )
        else util:log("info", ("Cannot remove ", $data-type, " ", $resource-name, ": it cannot be found"))
  )
};

(:~ return deep equality, using the convention of these tests:
 : an error element is returned if the items are unequal, otherwise, empty :)
declare function tcommon:deep-equal($node1 as node()*, $node2 as node()*) as element()? {
    let $equality := deepequality:equal-or-error($node1, $node2)
    where $equality/self::error
    return $equality
};

(:~ create a collection path with the given permissions :)
declare function tcommon:create-collection(
    $name as xs:string,
    $owner as xs:string,
    $group as xs:string,
    $permissions as xs:string
) {
  let $tokens := tokenize($name, "/")[.]
  for $token at $ctr in $tokens
  let $collection-so-far := "/" || string-join(subsequence($tokens, 1, $ctr), "/")
  let $collection-origin := "/" || string-join(subsequence($tokens, 1, $ctr - 1), "/")
  let $collection-new :=  $tokens[$ctr]
  return
    if (not(xmldb:collection-available($collection-so-far)))
    then
        system:as-user("admin", $magic:password, (
            let $create := xmldb:create-collection($collection-origin, $collection-new)
            let $owner := sm:chown(xs:anyURI($collection-so-far), $owner)
            let $group := sm:chgrp(xs:anyURI($collection-so-far), $group)
            let $perm := sm:chmod(xs:anyURI($collection-so-far), $permissions)
            return ()
            )
        )
    else ()
};