xquery version "1.0";
(:~ task to find uncached resources and schedule the background
 : task to execute them
 :  
 : Copyright 2011 Efraim Feinstein <efraim@opensiddur.org>
 : Licensed under the GNU Lesser General Public License, version 3 or later
 :)
import module namespace paths="http://jewishliturgy.org/modules/paths"
  at "/code/modules/paths.xqm";
import module namespace jcache="http://jewishliturgy.org/modules/cache"
  at "/code/modules/cache-controller.xqm";
import module namespace jobs="http://jewishliturgy.org/apps/jobs"
  at "/code/apps/jobs/modules/jobs.xqm";

declare variable $local:task-id external;

if ($paths:debug)
then 
  util:log-system-out(
    concat('In uncached resource scheduler at ', string(current-dateTime()))
  )
else (),
let $documents :=
  system:as-user('admin', $magicpassword,
    collection('/group')//tei:TEI/document-uri(root(.))
  )
for $document in $documents
where not(jcache:is-up-to-date($document))
return
  jobs:enqueue-unique(
    element jobs:job {
      element jobs:run {
        element jobs:query { '/code/apps/jobs/queries/bg-cache.xql' }
        element jobs:param {
          element jobs:name { 'resource' },
          element jobs:value { $document }
        }
      }
    },
    'admin', $magicpassword
  )
