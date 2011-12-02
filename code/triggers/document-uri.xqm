xquery version "1.0";

(:
	This trigger should run on document creation and update events.

  It adds @jx:document-uri to the root element iff it is tei:TEI, otherwise pass the file through unchanged.
  $exempt-collections excludes collections that end with that name from the trigger

  Copyright 2010-2011 Efraim Feinstein
  Open Siddur Project
  Licensed under the GNU Lesser General Public License, version 3 or later
:)
module namespace trigger='http://jewishliturgy.org/triggers/document-uri';

import module namespace xmldb="http://exist-db.org/xquery/xmldb";
import module namespace util="http://exist-db.org/xquery/util";

declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace jx="http://jewishliturgy.org/ns/jlp-processor";

(: exempt certain collections and sub-collections from document-uri triggering :)
declare function trigger:is-exempt(
  $uri as xs:anyURI)
  as xs:boolean {
  let $exempt-collections := ('tests', 'test', 'updated.xml')
  let $collections := tokenize($uri,'/')
  return $collections = $exempt-collections
};

declare function trigger:log-trigger-event($uri as xs:anyURI, $event as xs:string) {
  util:log-system-out(('TRIGGER: document-uri.xql called: ', $event, ' on ', $uri))
};

declare function trigger:write-document-uri($uri as xs:anyURI) {
  if (not(util:is-binary-doc($uri)) and doc-available($uri) and not(trigger:is-exempt($uri)))
  then
    (: the document is an XML document and it exists :)
    let $root := doc($uri)
    let $TEI := $root/tei:TEI
    let $full-uri := document-uri($root)
    where exists($TEI)
    return (# exist:batch-transaction #) {
      (: write @xml:base :)
      let $xmlbase := $root/tei:TEI/@xml:base
      where not($xmlbase = $full-uri)
      return update insert attribute xml:base {$full-uri} into $root/tei:TEI,
      (: write @jx:document-uri :)
      let $document-uri := $root/tei:TEI/@jx:document-uri
      where not($document-uri = $full-uri)
      return update insert attribute jx:document-uri {$full-uri} into $root/tei:TEI
    }
  else ()
};

declare function trigger:after-create-document($uri as xs:anyURI) {
  trigger:write-document-uri($uri),
  trigger:log-trigger-event($uri, 'create')
};

declare function trigger:after-update-document($uri as xs:anyURI) {
  trigger:write-document-uri($uri),
  trigger:log-trigger-event($uri, 'update')
};

declare function trigger:after-copy-document($new-uri as xs:anyURI, $uri as xs:anyURI) {
  trigger:log-trigger-event($new-uri, concat('copy 1 from ', string($uri))),
  trigger:write-document-uri($new-uri),
  trigger:log-trigger-event($new-uri, 'copy 2')
};

declare function trigger:after-move-document($new-uri as xs:anyURI, $uri as xs:anyURI) {
  trigger:write-document-uri($new-uri),
  trigger:log-trigger-event($new-uri, 'move')
};