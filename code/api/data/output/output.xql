xquery version "1.0";
(: api for output data, if a resource is not given
 : 
 : Parameters:
 : 	path = full path
 :	owner = name of owner to limit listing to|()
 :	If share-type is (), all accessible shares are shown
 :	If owner is (), all accessible shares with the given share-type are shown
 : 
 : Method: GET
 : Return: 
 :		200 + menu (menu of available outputs), 
 :		204 user exists but you are not logged in
 :		401 (you are not logged in and requested a resource that requires login)
 :		403 (you are logged in, but you can't access the resource), 
 :		404 share type, group or user does not exist
 :
 : Method: POST
 : Input: Password
 : Create a new XML resource in the given collection 
 : Return:
 :		201 Resource created, location header set
 :		401 Access to the resource requires authorization
 :		403 You are logged in, but you can't access the resource
 :		404 Share-type, user or group does not exist
 :		
 :
 : Open Siddur Project
 : Copyright 2011 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :
 :)
import module namespace response="http://exist-db.org/xquery/response";
import module namespace request="http://exist-db.org/xquery/request";
import module namespace xmldb="http://exist-db.org/xquery/xmldb";

import module namespace api="http://jewishliturgy.org/modules/api"
	at "/code/api/modules/api.xqm";
import module namespace app="http://jewishliturgy.org/modules/app"
	at "/code/modules/app.xqm";
import module namespace collab="http://jewishliturgy.org/modules/collab"
	at "/code/modules/collab.xqm";
import module namespace paths="http://jewishliturgy.org/modules/paths"
	at "/code/modules/paths.xqm";
import module namespace scache="http://jewishliturgy.org/modules/scache"
	at "/code/api/modules/scache.xqm";
import module namespace data="http://jewishliturgy.org/modules/data"
	at "/code/api/modules/data.xqm";

declare default element namespace "http://www.w3.org/1999/xhtml"; 
declare namespace html="http://www.w3.org/1999/xhtml";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace err="http://jewishliturgy.org/errors";

declare option exist:serialize "method=xhtml media-type=text/html omit-xml-declaration=no indent=yes 
        doctype-public=-//W3C//DTD&#160;XHTML&#160;1.1//EN
        doctype-system=http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd";


declare function local:get-menu(
	$share-type as xs:string?,
	$owner as xs:string?
	) as element() {
	let $user := app:auth-user()
	let $uri := request:get-uri()
	let $collections := 
	  let $top := data:top-collection($share-type, $owner)
	  return
	    if ($owner)
	    then $top
	    else 
        if ($user)
        then 
          for $group in xmldb:get-user-groups($user)
          return concat("/group/", $group)
        else ( (: TODO: allow public accessible outputs? :) )
	let $ignore-collections := '(/trash/)|(/cache/)'
	let $null := 
	  util:log-system-out(("Output for $collection = ", string-join($collections, ","), " $share-type =", $share-type, " $owner=", $owner))
	let $list :=
	(
		<ul class="common">{
			if (not($share-type))
			then (
				api:list-item('Group output', 
				  '/code/api/data/output/group', 
				  "GET", 
				  api:html-content-type(), 
				  ())
			)
			else if (not($owner))
			then (
				if ($user)
				then (
					for $group in xmldb:get-user-groups($user)
					return
						api:list-item($group, 
						  concat('/code/api/data/output/group/', $group), 
						  "GET", 
						  api:html-content-type(), 
						  ())
				)
				else ( (:do not display data about not logged in users :) )
			)
			else 
				( (: share type and owner present:) )
		}</ul>,
		if (exists($collections))
		then 
  		if (scache:is-up-to-date($collections, $uri, ""))
  		then scache:get-request($uri, '')
  		else scache:store($uri, '', 
  			<ul class="results">{
  				for $collection in $collections
  				let $output-collection := concat($collection, "/output")
  				where xmldb:collection-available($output-collection)
  				return
    				for $subcollection in xmldb:get-child-collections($output-collection)
    				let $collection-name := concat($output-collection, "/", $subcollection)
    				let $title := collection($collection-name)//html:title
    				let $doc-uri := concat($collection-name, "/", $subcollection, ".xhtml") 
    				  (:document-uri(root($title)):)
            let $null :=
              util:log-system-out(("subcollection = ", $collection-name, " $doc-uri=", $doc-uri))
    				let $doc-name-no-ext := 
    				  if ($title)
    				  then
    				    replace(util:document-name($doc-uri), '\.(xml|xhtml|html)$', '')
    				  else $subcollection
    				let $share-type-owner := 
              string-join(subsequence(tokenize($collection-name, '/'), 2, 2), '/')
    				let $link := 
    					concat('/code/api/data/output/', $share-type-owner, '/',
    						$doc-name-no-ext, 
    						'/'[exists($title)], 
    						$doc-name-no-ext[exists($title)])
    				let $title-string := 
    				  if ($title)
    				  then normalize-space($title)
    				  else $doc-name-no-ext
    				let $lang := $title/ancestor-or-self[@xml:lang][1]/@xml:lang
    				let $null := 
    				  util:log-system-out((
    				  "$doc-uri=", $doc-uri, 
    				  " available=", doc-available($doc-uri))
    				  )
    				where not(matches($doc-uri, $ignore-collections))
    				order by $title-string
    				return 
    						api:list-item(
    							<span>{
    								$lang, 
    								if ($lang) then attribute lang {string($lang)} else (),
    								$title-string
    							}</span>,
    							$link, "GET", api:html-content-type(), (),
                  (
                    if (doc-available($doc-uri))
                    then(
                      "xhtml", concat($link, ".xhtml"),
                      "css", concat($link, ".css"),
                      "db", replace($doc-uri, "^/db", "")
                    )
                    else (),
                    ("status", concat($link, "/status"))
                  )
    						)
  			}</ul>)
  		else ( (: no collections to browse :) )
	)
	let $n-results := count(scache:get($uri, '')/li)
	return (
		if ($paths:debug)
		then
			util:log-system-out(('GET ', $uri, ': $n-results=', $n-results))
		else (),
		api:list(
			<title>Open Siddur Output Data API</title>,
			$list,
			$n-results,
      true(),
      "GET",
      (api:html-content-type()),
      ()
		)
	)
};

(: output can be xhtml or css :)
declare function local:get(
	$path as xs:string,
	$format as xs:string
	) as item() {
  let $original-format := $format
	let $format := 
		if (not($format) or $format = 'html')
		then 'xhtml'
		else $format
	let $db-path := data:api-path-to-db(concat($path, if ($original-format) then '' else '.xhtml'))
	return (
	  util:log-system-out(("$db-path =", $db-path)),
		if ($format = 'xhtml')
		then 
			if (doc-available($db-path))
			then (
				api:serialize-as('html'),
				doc($db-path)
			)
			else
				api:error(404, "Not found", $path)
		else 
			if ($format = 'css')
			then 
				let $collection := util:collection-name($db-path)
				let $css := xmldb:get-child-resources($collection)[ends-with(.,'css')][1]
				return
					if ($css)
					then (  
						api:serialize-as('css'),
						util:binary-to-string(util:binary-doc(concat($collection, '/', $css)))
					)
					else
						api:error(404, "Not found", $path)
			else
				api:error(404, "Not found", $path)
  )
};

if (api:allowed-method('GET'))
then
	let $auth := api:request-authentication() or true()
	let $share-type := request:get-parameter('share-type', ())
	let $owner := request:get-parameter('owner', ())
	let $resource := request:get-parameter('resource', ())
	let $format := request:get-parameter('format', ())
	let $path := request:get-parameter('path', ())
	let $null := util:log-system-out(("path =", $path))
	return
		if (data:is-valid-share-type($share-type))
		then 
			if (data:is-valid-owner($share-type, $owner))
			then 
				if ($resource)
				then local:get($path, $format)
				else local:get-menu($share-type, $owner)
			else
				api:error(404, concat("Invalid owner for the given share type ", $share-type), $owner)
		else
			api:error(404, "Invalid share type. Acceptable values are 'group'", $share-type) 
else
	(: disallowed method :) 
	()
