# non-active maven artifacts: shape and remediation (May 2026)

175 critical Maven Central artifacts whose repos are not actively maintained, across 136 repos. Maven has the lowest dead share of the large registries (7.3%) and 37% non-active overall. No download counts; concentration uses dependent-repo counts. Only 73 of 136 repos could be measured for size (the rest are off-GitHub or shared with other ecosystems).

| bucket | n | meaning |
|---|---:|---|
| dormant | 36 | no maintainer activity in a year, but no evidence they've left |
| dead | 27 | archived, or people have knocked and nobody answered |
| unknown | 73 | too quiet to tell; nobody has filed anything to test responsiveness |

(Packages, not repos; one repo often publishes several artifacts.)

## summary

Maven is the migration ecosystem. 58% of these artifacts have a named successor to switch to and only 2% are small enough to vendor, both extremes among the seven registries. The Java world has been through several coordinated namespace moves (javax→jakarta, JUnit 4→5, Log4j 1→2, Jackson 1→2, com.sun.jersey→glassfish, mortbay jetty→eclipse) and most of the non-active set is old coordinates left behind by one of them. The "unmaintained" artifact is usually a previous name for something that is very much maintained under a new groupId.

| remediation | n | % | rubygems % | go % | pypi % | cargo % | packagist % | npm % | meaning |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| switch | 102 | 58% | 19% | 32% | 28% | 23% | 38% | 17% | move to a named, maintained successor |
| accept | 54 | 31% | 50% | 41% | 39% | 39% | 31% | 39% | keep it, pin the version, carry the risk; no good exit exists |
| switch-piecemeal | 15 | 9% | 1% | 4% | 8% | 1% | 1% | 2% | replace the slice you use with two or three smaller packages |
| vendor | 4 | 2% | 27% | 21% | 20% | 34% | 27% | 41% | copy the source into your tree and drop the dependency |
| adopt | 0 | 0% | 2% | 1% | 4% | 3% | 2% | 1% | take over maintenance |

## large by default

Of the 73 repos measured the mean is 69,888 lines, 2.4× Go and 40× rubygems. 53 (73%) are over 3,000 lines and only 5 are under 300. Maven artifacts are libraries and frameworks, not utilities; vendoring is almost never on the table.

| size | maven | go | pypi | npm | rubygems |
|---|---:|---:|---:|---:|---:|
| under 300 lines | 7% | 10% | 4% | 40% | 41% |
| 3,000+ | 73% | 35% | 37% | 8% | 11% |

20 of 73 measured repos (27%) are archived.

## named successors

95 of 175 (54%), the highest rate of any registry. The javax→jakarta migration alone:

  * `javax.servlet:javax.servlet-api` → jakarta.servlet
  * `javax.inject:javax.inject` → jakarta.inject
  * `javax.annotation:javax.annotation-api` → jakarta.annotation
  * `javax.mail:mail`, `com.sun.mail:javax.mail`, `javax.mail:javax.mail-api` → jakarta.mail
  * `javax.xml.bind:jaxb-api` → jakarta.xml.bind
  * `javax.persistence:javax.persistence-api`, `org.hibernate.javax.persistence:*` → jakarta.persistence
  * `javax.ws.rs:javax.ws.rs-api` → jakarta.ws.rs
  * `javax.transaction`, `javax.websocket`, `javax.json`, `javax.enterprise:cdi-api`, `javax.cache`, `javax.servlet.jsp*`, `com.sun.faces:*` → jakarta.*

Other coordinate migrations:

  * `junit:junit` → org.junit.jupiter
  * `log4j:log4j`, `org.slf4j:slf4j-log4j12` → log4j2
  * `org.codehaus.jackson:*` → com.fasterxml.jackson
  * `com.sun.jersey:*` → org.glassfish.jersey
  * `org.mortbay.jetty:*` → org.eclipse.jetty
  * `cglib:cglib`, `cglib:cglib-nodep` → byte-buddy
  * `commons-httpclient` → org.apache.httpcomponents
  * `io.springfox:*` → springdoc-openapi
  * `com.google.code.findbugs:annotations` → spotbugs
  * `postgresql:postgresql` → org.postgresql:postgresql
  * `xmlunit:xmlunit` → org.xmlunit:xmlunit2
  * `com.relevantcodes:extentreports` → com.aventstack:extentreports
  * `com.mashape.unirest:unirest-java` → com.konghq:unirest-java
  * `net.sf.ehcache:ehcache-core` → org.ehcache
  * `org.bouncycastle:bcprov-jdk16` → bcprov-jdk18on
  * `org.springframework.cloud:spring-cloud-starter-sleuth`, `-zipkin` → micrometer-tracing
  * `com.github.stefanbirkner:system-rules` → system-lambda
  * `net.java.dev.jets3t:jets3t` → aws-sdk s3

Editorial; alternatives in the same space:

  * `org.hsqldb:hsqldb`, `hsqldb:hsqldb` → h2
  * `org.hamcrest:*`, `org.easytesting:fest-assert*`, `org.skyscreamer:jsonassert` → assertj
  * `commons-dbcp`, `com.jolbox:bonecp` → HikariCP
  * `org.apache.velocity:*`, `org.apache.tiles:*`, `opensymphony:sitemesh` → thymeleaf / freemarker
  * `net.sf.ehcache:ehcache` → caffeine
  * `com.jcraft:jsch` → mina-sshd
  * `net.sourceforge.nekohtml` → jsoup
  * `net.sf.dozer:dozer` → mapstruct
  * `args4j` → picocli
  * `com.squareup.picasso:picasso` → coil
  * `com.android.volley:volley` → okhttp
  * `net.sourceforge.jtds:jtds` → mssql-jdbc

Wrong: `org.apache.commons:commons-math3` → commons-math (math3 is newer; the next version is math4), `org.hibernate.javax.persistence:hibernate-jpa-2.1-api` → javax.persistence (should be jakarta), `org.jasypt:jasypt` → bouncycastle (different purpose).

## open questions

How much of Maven's 58% switch share is the Jakarta migration specifically, versus a general Java pattern of coordinate renames. And whether the 31% `accept` set is genuinely orphaned or just artifacts under old groupIds whose code lives on elsewhere; Maven's groupId:artifactId addressing makes "moved" look like "dead" more than other registries.
