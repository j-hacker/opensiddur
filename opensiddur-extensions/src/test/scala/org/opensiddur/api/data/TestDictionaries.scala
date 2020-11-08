package org.opensiddur.api.data

import org.opensiddur.DbTest

trait CommonTestDictionaries {
  val prolog =
    """xquery version '3.1';
      import module namespace tcommon="http://jewishliturgy.org/test/tcommon"
       at "xmldb:exist:/db/apps/opensiddur-server/test/tcommon.xqm";

      import module namespace dict="http://jewishliturgy.org/api/data/dictionaries"
        at "xmldb:exist:///db/apps/opensiddur-server/api/data/dictionaries.xqm";
      import module namespace magic="http://jewishliturgy.org/magic"
        at "xmldb:exist:///db/apps/opensiddur-server/magic/magic.xqm";
                
      declare namespace html="http://www.w3.org/1999/xhtml";
      declare namespace tei="http://www.tei-c.org/ns/1.0";
      declare namespace j="http://jewishliturgy.org/ns/jlptei/1.0";
      declare namespace http="http://expath.org/ns/http-client";
      declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
      declare namespace a="http://jewishliturgy.org/ns/access/1.0";
      """
}

class TestDictionaries extends DbTest with CommonTestDictionaries {
  override def beforeAll()  {
    super.beforeAll()

    setupUsers(2)
    setupResource("src/test/resources/api/data/dictionaries/Existing.xml", "Existing", "dictionaries", 1, Some("en"))
    setupResource("src/test/resources/api/data/dictionaries/Existing.xml", "NoAccess", "dictionaries",  2,
      Some("en"), Some("everyone"), Some("rw-------"))
    setupResource("src/test/resources/api/data/notes/Existing.xml", "NoWriteAccess", "dictionaries", 2,
      Some("en"), Some("everyone"), Some("rw-r--r--"))
  }

  override def afterAll()  {
    teardownResource("NoWriteAccess", "dictionaries", 2)
    teardownResource("NoAccess", "dictionaries", 2)
    teardownResource("Existing", "dictionaries", 1)
    teardownResource("Valid", "dictionaries", 1)
    teardownUsers(2)

    super.afterAll()
  }

  override def beforeEach(): Unit = {
    super.beforeEach()
  }

  override def afterEach(): Unit = {
    super.afterEach()
  }

  describe("dict:get") {
    it("gets an existing resource") {
      xq("""dict:get("Existing")""")
        .assertXPath("""exists($output/tei:TEI)""", "Returns a TEI resource")
        .go
    }
    
    it("fails to get a nonexisting resource") {
      xq("""dict:get("DoesNotExist")""")
        .assertHttpNotFound
        .go
    }
    
    it("fails to get a resource with no read access") {
      xq("""dict:get("NoAccess")""")
        .assertHttpNotFound
        .go
    }
  }  

  describe("dict:list") {
    it("lists all resources") {
      xq("""dict:list("", 1, 100)""")
        .user("xqtest1")
        .assertSearchResults
        .assertXPath("""count($output//html:li[@class="result"])>=1""", "returns at least 1 result")
        .assertXPath("""
          every $li in $output//html:li[@class="result"]
          satisfies exists($li/html:a[@class="alt"][@property="access"])
        """, "results include a pointer to access API")
        .go
    }

    it("does not list resources with no access when unauthenticated") {
      xq("""dict:list("", 1, 100)""")
        .assertSearchResults
        .assertXPath("""count($output//html:li[@class="result"])>=1""", "returns at least 1 result")
        .assertXPath("""empty($output//html:li[@class="result"]/html:a[@class="document"]/@href[contains(., "NoAccess")])""", 
          "does not list resource with no read access")
        .go
    }
    
    it("lists some resources") {
      xq("""dict:list("", 1, 2)""")
        .user("xqtest1")
        .assertXPath("""count($output//html:li[@class="result"])=2""", "returns 2 results")
        .assertSearchResults
        .go
    }
    
    it("responds to a query") {
      xq("""dict:list("Query", 1, 100)""")
        .assertXPath("""count($output//html:ol[@class="results"]/html:li)=1""", "returns 1 result")
        .assertSearchResults
        .go
    }
  }
  
  describe("dict:post") {
    val validDoc = readXmlFile("src/test/resources/api/data/dictionaries/Valid.xml")
    val invalidDoc = readXmlFile("src/test/resources/api/data/dictionaries/Invalid.xml")
    it("posts a valid resource") {
      xq(s"""dict:post(document { $validDoc })""")
        .user("xqtest1")
        .assertHttpCreated
        .assertXPathEquals("collection('/db/data/dictionaries/en')[util:document-name(.)=tokenize($output//http:header[@name='Location']/@value,'/')[last()] || '.xml']//tei:revisionDesc/tei:change[1]",
          "a change record has been added",
          """<tei:change xmlns:tei="http://www.tei-c.org/ns/1.0" type="created" who="/user/xqtest1"
                        when="..."/>"""
        )
        .go
    }
    
    it("fails to post a valid resource unauthenticated") {
      xq(s"""dict:post(document { $validDoc })""")
        .assertHttpUnauthorized
        .go
    }
    
    it("fails to post an invalid resource") {
      xq(s"""dict:post(document { $invalidDoc })""")
        .user("xqtest1")
        .assertHttpBadRequest
        .go
    }
  }

  describe("dict:put") {
    
    it("puts a valid resource to an existing resource") {
      val validDoc = readXmlFile("src/test/resources/api/data/dictionaries/Existing-After-Put.xml")
      xq(s"""dict:put("Existing", document { $validDoc })""")
        .user("xqtest1")
        .assertHttpNoData
        .assertXPathEquals("""doc('/db/data/dictionaries/en/Existing.xml')//tei:revisionDesc/tei:change[1]""",
          "a change record has been added",
          """<tei:change xmlns:tei="http://www.tei-c.org/ns/1.0" type="edited" who="/user/xqtest1"
                        when="..."/>"""
        )
        .go
    }
    
    it("fails to put a resource when unauthenticated") {
        val validDoc = readXmlFile("src/test/resources/api/data/dictionaries/Existing-After-Put.xml")
        xq(s"""dict:put("Existing", document { $validDoc })""")
          .assertHttpUnauthorized
          .go
    }
    
    it("fails to put a valid resource to a nonexisting resource") {
      val validDoc = readXmlFile("src/test/resources/api/data/dictionaries/Valid.xml")
      xq(s"""dict:put("DoesNotExist", document { $validDoc })""")
        .user("xqtest1")
        .assertHttpNotFound
        .go
    }
    
    it("fails to put an invalid resource") {
      val invalidDoc = readXmlFile("src/test/resources/api/data/dictionaries/Invalid.xml")
      xq(s"""dict:put("Existing", document { $invalidDoc })""")
        .user("xqtest1")
        .assertHttpBadRequest
        .go
    }

    it("fails to put an resource that was invalidated by an illegal change") {
      val invalidDoc = readXmlFile("src/test/resources/api/data/dictionaries/Invalid-After-Put.xml")
      xq(s"""dict:put("Existing", document { $invalidDoc })""")
        .user("xqtest1")
        .assertHttpBadRequest
        .go
    }
  }

  describe("dict:get-access") {
    it("gets an access document for an existing resource") {
      xq("""dict:get-access("Existing", ())""")
        .assertXPath("""$output/self::a:access""", "an access structure is returned")
        .go
    }

    it("fails to get access for a nonexistent resource") {
      xq("""dict:get-access("DoesNotExist", ())""")
        .assertHttpNotFound
        .go
    }
  }
  
  describe("dict:put-access") {
    it("sets access with a valid access structure") {
      xq("""dict:put-access("Existing", document{
        <a:access>
          <a:owner>xqtest1</a:owner>
          <a:group write="true">everyone</a:group>
          <a:world write="true" read="true"/>
        </a:access>
      })""")
        .user("xqtest1")
        .assertHttpNoData
        .go
    }

    it("fails with an invalid access structure") {
      xq("""dict:put-access("Existing", document { <a:access>
          <a:invalid/>
        </a:access> })""")
        .user("xqtest1")
        .assertHttpBadRequest
        .go
    }

    it("fails for a resource with no write access") {
      xq("""dict:put-access("NoWriteAccess", document{
        <a:access>
          <a:owner>xqtest1</a:owner>
          <a:group write="true">everyone</a:group>
          <a:world write="true" read="true"/>
        </a:access>
      })""")
        .user("xqtest1")
        .assertHttpForbidden
        .go
    }

    it("fails for a nonexistent resource") {
      xq("""dict:put-access("DoesNotExist", document{
        <a:access>
          <a:owner>xqtest1</a:owner>
          <a:group write="true">everyone</a:group>
          <a:world write="true" read="true"/>
        </a:access>
      })""")
        .user("xqtest1")
        .assertHttpNotFound
        .go
    }
    
    it("fails to change access unauthenticated") {
      xq("""dict:put-access("Existing", document{
        <a:access>
          <a:owner>xqtest1</a:owner>
          <a:group write="false">everyone</a:group>
          <a:world read="false" write="false"/>
        </a:access>
        })""")
        .assertHttpUnauthorized
        .go
    }
  }

}

class TestDictionariesDelete extends DbTest with CommonTestDictionaries {

  override def beforeEach(): Unit = {
    super.beforeEach()

    setupUsers(2)
    setupResource("src/test/resources/api/data/dictionaries/Existing.xml", "Existing", "dictionaries", 1, Some("en"))
    setupResource("src/test/resources/api/data/dictionaries/Existing.xml", "NoWriteAccess", "dictionaries", 2,
      Some("en"), Some("everyone"), Some("rw-r--r--"))
  }

  override def afterEach(): Unit = {
    super.afterEach()

    teardownResource("Existing", "dictionaries", 1)
    teardownResource("NoWriteAccess", "dictionaries", 2)
    teardownUsers(2)
  }

  describe("dict:delete") {
    it("removes an existing resource") {
      xq("""dict:delete("Existing")""")
        .user("xqtest1")
        .assertHttpNoData
        .go
    }
    
    it("does not remove an existing resource when unauthenticated") {
      xq("""dict:delete("Existing")""")
        .assertHttpUnauthorized
        .go
    }

    it("fails to remove a nonexisting resource") {
      xq("""dict:delete("DoesNotExist")""")
        .user("xqtest1")
        .assertHttpNotFound
        .go
    }

    it("fails to remove a resource without write access") {
      xq("""dict:delete("NoWriteAccess")""")
        .user("xqtest1")
        .assertHttpForbidden
        .go
    }
  }
}