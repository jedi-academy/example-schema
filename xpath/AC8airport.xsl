<?xml version="1.0" encoding="UTF-8"?>

<!--
    Document   : AC8airport.xsl
    Created on : March 3, 2011, 2:11 PM
    Author     : jim
    Description:
        This XSL stylesheet produces a list of flights, with some nasty XPath to calculate
        the average speed for each flight.
        Got table lookup ideas from http://www.ibm.com/developerworks/xml/library/x-xsltip.html
        Got xsl:variable ideas from http://www.xml.com/pub/a/2001/02/07/trxml9.html

        NOTE: I added an airline attribute to the root element, to provide a dummy
        key  that I could use to create a node set of instance elements.
        NOTE: I had to add a distance attribute, to the destination element.

        This XSL has been adapted from the solution for the flight-centric XML data

        NOTE NOTE NOTE   This is not complete, but I am out of time :(     NOTE NOTE NOTE
-->

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="2.0"
    xmlns:tz="http://time-zones.data" xmlns:ac="http://airport-codes.data">
    <xsl:output method="html"/>

    <!-- we need to use a key so that we can get instances back in a nodeset rather than a tree fragment -->
    <xsl:key name="instant" match="flight" use="../../../@airline"/>

    <!-- Basic structure for the resulting transformation -->
    <xsl:template match="/">
        <html>
            <head>
                <title>Flight Analysis</title>
            </head>
            <body>
                <h2>Airport-centric data</h2>
                <xsl:call-template name="analysis"/>
            </body>
        </html>
    </xsl:template>

    <!-- template for the analysis table that is the goal of this XSL -->
    <xsl:template name="analysis">
        <h1>Flight Performance Analysis</h1>
        <table>
            <!-- Table column headings -->
            <tr>
                <th>Flight #</th>
                <th>Origin</th>
                <th>Leaves at</th>
                <th>Destination</th>
                <th>Arrives at</th>
                <th>Elapsed time</th>
                <th>Distance</th>
                <th>Average Speed</th>
            </tr>
            <tr>
                <th></th>
                <th></th>
                <th>(hhmm)</th>
                <th></th>
                <th>(hhmm)</th>
                <th>(mins)</th>
                <th>(miles)</th>
                <th>(m.p.h.)</th>
            </tr>

            <!-- Individual rows, one per flight -->
            <xsl:for-each select="//flight">
                <xsl:sort select="@num" data-type="number"/>
                <xsl:call-template name="flight"/>
            </xsl:for-each>

            <!-- The summary line, with averages -->
            <tr>
                <!-- Calculate some totals -->
                <xsl:variable name="total-distance" select="sum(//flight/../@distance)"/>
                <!-- Use a recursive template to calculate total elapsed time -->
                <xsl:variable name="total-elapsed">
                    <xsl:call-template name="calc-elapsed">
                        <xsl:with-param name="data" select="key('instant','AC')"/>
                    </xsl:call-template>
                </xsl:variable>
                <xsl:variable name="number-flights" select="count(//flight"/>
                <!-- spit out the row, with averages calculated -->
                <th>
                    <xsl:value-of select="count(//flight)"/>
                </th>
                <th></th>
                <th></th>
                <th></th>
                <th></th>
                <th>
                    <xsl:value-of select="format-number($total-elapsed div $number-flights,'#.#')" />
                </th>
                <th>
                    <xsl:value-of select="format-number($total-distance div $number-flights,'#.#')"/>
                </th>
                <th>
                    <xsl:value-of select="format-number($total-distance div $total-elapsed * 60,'#.#')"/>
                </th>
            </tr>
        </table>
    </xsl:template>

    <!-- template to perform the calculations and present a single flight -->
    <xsl:template name="flight">
        <!-- lookup the departure airport -->
        <xsl:variable name="departing-name" select="../../@city"/>
        <!-- lookup the destination airport -->
        <xsl:variable name="arriving-name" select="../@city"/>
        <!-- calculate the flight duration -->
        <xsl:variable name="minutes-elapsed">
            <xsl:call-template name="elapsed-time"/>
        </xsl:variable>
        <!-- and spit out the table row -->
        <tr>
            <td>
                <xsl:value-of select="@num"/>
            </td>
            <td>
                <xsl:value-of select="$departing-name"/>
            </td>
            <td>
                <xsl:value-of select="@leave"/>
            </td>
            <td>
                <xsl:value-of select="$arriving-name"/>
            </td>
            <td>
                <xsl:value-of select="@arrive"/>
            </td>
            <td>
                <xsl:value-of select="format-number($minutes-elapsed,'#.#')"/>
            </td>
            <td>
                <xsl:value-of select="format-number(../@distance,'#.#')"/>
            </td>
            <td>
                <xsl:variable name="speed" select="(../@distance div $minutes-elapsed) * 60"/>
                <xsl:value-of select="format-number($speed,'#.#')"/>
            </td>
        </tr>
    </xsl:template>

    <!-- a template (function?) to calculate the duration of a flight instance, in minutes -->
    <xsl:template name="elapsed-time">
        <!-- take into account timezone differences, based on the airport -->
        <xsl:variable name="departing-adj">
            <xsl:apply-templates select="$timezones-top">
                <xsl:with-param name="airport-code" select="../../@code"/>
            </xsl:apply-templates>
        </xsl:variable>
        <xsl:variable name="arriving-adj">
            <xsl:apply-templates select="$timezones-top">
                <xsl:with-param name="airport-code" select="../@code"/>
            </xsl:apply-templates>
        </xsl:variable>
        <!-- Calculate the minutes, given the HHMM format that time was stored in -->
        <xsl:variable name="arriving-minutes" select="floor(@arrive div 100) * 60 + (@arrive mod 100)"/>
        <xsl:variable name="leaving-minutes" select="floor(@leave div 100) * 60 + (@leave mod 100)"/>
        <xsl:variable name="minutes-adj" select="($departing-adj - $arriving-adj) * 60"/>
        <!-- Adjust if needed for a next-day arrival -->
        <xsl:variable name="day-adjustment">
            <xsl:choose>
                <xsl:when test="@nextday='y'">
                    <xsl:value-of select="24 * 60"/>
                </xsl:when>
                <xsl:otherwise>
                            0
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <!-- and finally, the meat of the matter -->
        <xsl:value-of select="$arriving-minutes - $leaving-minutes + $minutes-adj + $day-adjustment"/>
    </xsl:template>

    <!-- template (function?) to calculate recursively total elapsed time -->
    <xsl:template name="calc-elapsed">
        <xsl:param name="data"/>
        <xsl:choose>
            <!-- Deal with the recursive case -->
            <xsl:when test="count($data) > 1">
                <xsl:variable name="result">
                    <xsl:call-template name="calc-elapsed">
                        <xsl:with-param name="data" select="$data[position() > 1]"/>
                    </xsl:call-template>
                </xsl:variable>
                <xsl:variable name="this1">
                    <xsl:for-each select="$data[position() = 1]">
                        <xsl:call-template name="elapsed-time"/>
                    </xsl:for-each>
                </xsl:variable>
                <xsl:value-of select="$this1 + $result"/>
            </xsl:when>
            <!-- Deal with the base case -->
            <xsl:otherwise>
                <xsl:for-each select="$data[position() = 1]">
                    <xsl:call-template name="elapsed-time"/>
                </xsl:for-each>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <!-- Use an XSL table lookup, with a different namespace, to get the airport timezone delta -->
    <xsl:key name="timezone-lookup" match="tz:airport" use="tz:code"/>
    <xsl:variable name="timezones-top" select="document('')/*/tz:airports"/>
    <xsl:template match="tz:airports">
        <xsl:param name="airport-code"/>
        <xsl:value-of select="key('timezone-lookup', $airport-code)/tz:gmt"/>
    </xsl:template>
    <tz:airports>
        <tz:airport>
            <tz:code>YVR</tz:code>
            <tz:gmt>-8</tz:gmt>
        </tz:airport>
        <tz:airport>
            <tz:code>YYC</tz:code>
            <tz:gmt>-7</tz:gmt>
        </tz:airport>
        <tz:airport>
            <tz:code>TTZ</tz:code>
            <tz:gmt>-5</tz:gmt>
        </tz:airport>
    </tz:airports>


</xsl:stylesheet>
