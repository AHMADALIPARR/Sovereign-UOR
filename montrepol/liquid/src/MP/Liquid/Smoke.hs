-- SPDX-License-Identifier: AGPL-3.0-or-later

module MP.Liquid.Smoke (clampNat) where

{-@ clampNat :: Int -> {v:Int | v >= 0} @-}
clampNat :: Int -> Int
clampNat x = if x < 0 then 0 else x
