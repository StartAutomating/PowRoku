﻿<#
.Synopsis
    Tests for PowRoku
.Description
    Simple tests for PowRoku.
.Notes
    It's a little tricky to test a local device up in a cloud-based CI/CD.

    As such, this predominately tests Send-Roku with a virtual IP.

    As almost all functions derive from this one, this should ensure the module communicates with a Roku correctly.
#>
#requires -Module PowRoku

describe "PowRoku" {
    it 'Can send keys to a Roku' {
        $whatIf = Send-Roku -IPAddress ([IPAddress]::Loopback) -KeyPress VolumeUp -WhatIf
        $whatIf.Uri |Should -BeLike */keypress/VolumeUp
        $whatIf.Method |Should -Be POST
    }

    it 'Can send a command to a Roku' {
        $whatIf = Send-Roku -IPAddress ([IPAddress]::Loopback) -Command query/device-info -WhatIf
        $whatIf.Uri |Should -BeLike */query/device-info
        $whatIf.Method |Should -Be GET
    }

    it 'Can send text to a Roku' {
        $whatIf = Send-Roku -IPAddress ([IPAddress]::Loopback) -Text 'Rick & Morty' -WhatIf
        $whatIf[0].Uri |Should -BeLike */keypress/Lit_R
        $whatIf[5].Uri |Should -BeLike */keypress/Lit_%26
    }
}