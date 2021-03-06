{-# LANGUAGE TemplateHaskell, QuasiQuotes #-}

-- | Idiom brackets. Vixey's idea.

module Control.Applicative.QQ.Idiom (i) where

import Control.Applicative ((<*>), pure)
import Control.Monad ((<=<))
import Language.Haskell.Meta (parseExp)
import Language.Haskell.TH.Lib
import Language.Haskell.TH.Quote
import Language.Haskell.TH.Syntax

-- | Turns function application into '<*>', and puts a 'pure' on the beginning.
--
-- > [i| subtract [1,2,3] [10,20,30] |]
-- > -> pure subtract <*> [1,2,3] <*> [10,20,30]
-- > -> [9,19,29,8,18,28,7,17,27]
--
-- Does not apply to nested applications:
--
-- > getZipList [i| subtract (ZipList [1,2,3]) (ZipList [10,20,30]) |]
-- > -> getZipList (pure subtract <*> ZipList [1,2,3] <*> ZipList [10,20,30])
-- > -> [9,18,27]
--
-- Will treat @[i| x \`op\` y |]@ as @[i| op x y |]@ as long as neither x nor y
-- are an infix expression. If they are, will likely complain that it doesn't
-- have fixity information (unless haskell-src-meta becomes clever enough to
-- resolve that itself).
i :: QuasiQuoter
i = QuasiQuoter { quoteExp = applicate <=< either fail return . parseExp,
  quotePat = nonsense "pattern",
  quoteType = nonsense "type",
  quoteDec = nonsense "dec" }
 where
  nonsense context = fail $ "You can't use idiom brackets in " ++ context ++
    " context, that doesn't even make sense."

applicate :: Exp -> ExpQ
applicate (AppE f x) =
  [| $(applicate f) <*> $(return x) |]
applicate (InfixE (Just left) op (Just right)) =
  [| pure $(return op) <*> $(return left) <*> $(return right) |]
applicate (UInfixE left op right) = case (left,right) of
  (UInfixE{}, _) -> ambig
  (_, UInfixE{}) -> ambig
  (_, _) -> [| pure $(return op) <*> $(return left) <*> $(return right) |]
 where
  ambig = fail "Ambiguous infix expression in idiom bracket."
applicate x = [| pure $(return x) |]

