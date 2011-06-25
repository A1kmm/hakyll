-- | Representation of a directed graph. In Hakyll, this is used for dependency
-- tracking.
--
module Hakyll.Core.DirectedGraph
    ( DirectedGraph
    , fromList
    , toList
    , member
    , nodes
    , neighbours
    , reverse
    , reachableNodes
    , findCycle
    ) where

import Prelude hiding (reverse)
import Control.Arrow (second)
import Control.Monad (msum)
import Data.Monoid (mconcat)
import Data.Set (Set)
import Data.Maybe (fromMaybe)
import qualified Data.Map as M
import qualified Data.Set as S
import qualified Prelude as P

import Hakyll.Core.DirectedGraph.Internal

-- | Construction of directed graphs
--
fromList :: Ord a
         => [(a, Set a)]     -- ^ List of (node, reachable neighbours)
         -> DirectedGraph a  -- ^ Resulting directed graph
fromList = DirectedGraph . M.fromList . map (\(t, d) -> (t, Node t d))

-- | Deconstruction of directed graphs
--
toList :: DirectedGraph a
       -> [(a, Set a)]
toList = map (second nodeNeighbours) . M.toList . unDirectedGraph

-- | Check if a node lies in the given graph
--
member :: Ord a
       => a                -- ^ Node to check for
       -> DirectedGraph a  -- ^ Directed graph to check in
       -> Bool             -- ^ If the node lies in the graph
member n = M.member n . unDirectedGraph

-- | Get all nodes in the graph
--
nodes :: Ord a
      => DirectedGraph a  -- ^ Graph to get the nodes from
      -> Set a            -- ^ All nodes in the graph
nodes = M.keysSet . unDirectedGraph

-- | Get a set of reachable neighbours from a directed graph
--
neighbours :: Ord a
           => a                -- ^ Node to get the neighbours of
           -> DirectedGraph a  -- ^ Graph to search in
           -> Set a            -- ^ Set containing the neighbours
neighbours x = fromMaybe S.empty . fmap nodeNeighbours
             . M.lookup x . unDirectedGraph

-- | Reverse a directed graph (i.e. flip all edges)
--
reverse :: Ord a
        => DirectedGraph a
        -> DirectedGraph a
reverse = mconcat . map reverse' . M.toList . unDirectedGraph
  where
    reverse' (id', Node _ neighbours') = fromList $
        zip (S.toList neighbours') $ repeat $ S.singleton id'

-- | Find all reachable nodes from a given set of nodes in the directed graph
--
reachableNodes :: Ord a => Set a -> DirectedGraph a -> Set a
reachableNodes set graph = reachable (setNeighbours set) set
  where
    reachable next visited
        | S.null next = visited
        | otherwise = reachable (sanitize neighbours') (next `S.union` visited)
      where
        sanitize = S.filter (`S.notMember` visited)
        neighbours' = setNeighbours (sanitize next)

    setNeighbours = S.unions . map (`neighbours` graph) . S.toList

-- | Find a cycle, starting from a certain node
--
findCycle :: Ord a => DirectedGraph a -> Maybe [a]
findCycle graph = msum $ map (findCycle' [] S.empty) $ S.toList $ nodes graph
  where
    findCycle' stack visited x
        | x `S.member` visited = Just $ dropWhile (/= x) $ P.reverse stack'
        | otherwise = msum $ map (findCycle' stack' visited') nb
      where
        nb = S.toList $ neighbours x graph
        stack' = x : stack
        visited' = S.insert x visited
