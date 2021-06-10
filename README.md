# Semicircle
Copyright 2021 Cadence Design Systems, Inc. All rights reserved worldwide.

Glyph script that automatically generates half-OH topology between two connectors that form a closed loop.

## Operation
The main purpose of this script is to help expidite the manual generation of structured topology in the area between two connectors that form a closed loop. It can be thought of as a half-OH topology, as it produces a topology geometrically similar to the upper (or lower) half of an OH grid.

To run, simply highlight two connectors or one unstructured domain with an edge defined by two connectors and execute the script (for versions >= 17.2R2), or execute the script and then select the connectors/domain. The topology will be automatically created. There is a dimension in the operation that is subject to contraints, but can be chosen automatically based on an optimal value. However, if you would like control over this value, there is a flag in the script on line 39 that allows you to use a GUI.

On line 37, the input(AutoDim) variable should be used with caution. This prompts the script to automatically adjust the dimension of some connectors that are not dimensionally consistent. While logic is included to try and prevent any changes resulting in unbalanced domains, this can sometimes fail, resulting in undesired behavior.

![ScriptImage](https://raw.github.com/pointwise/Semicircle/master/ScriptImage.png)

## Disclaimer
This file is licensed under the Cadence Public License Version 1.0 (the "License"), a copy of which is found in the LICENSE file, and is distributed "AS IS." 
TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, CADENCE DISCLAIMS ALL WARRANTIES AND IN NO EVENT SHALL BE LIABLE TO ANY PARTY FOR ANY DAMAGES ARISING OUT OF OR RELATING TO USE OF THIS FILE. 
Please see the License for the full text of applicable terms.
