{-|
Module      : SymbolTable
Description : Contains functions used for working with symbol table.
-}
module SymbolTable.SymbolTable where

import Data.List
import Data.Maybe

import AST.AST

data SymbolTable = SymbolTable
    { modelSymbolTables :: [ModelSymbolTable] -- All class symbol tables for all classes to be compiled
    } deriving (Eq, Show)

data ModelSymbolTable = ModelSymbolTable
    { stModelName       :: String -- class name
    , stModelType       :: ModelType
    , imports         :: [ModelImport]
    , publicVariables :: [(String, String)] -- (variable name, variable type name) list of variable
    , methods         :: [(String, MethodSymbolTable)] -- (method name, method symbol) list of methods
    } deriving (Eq, Show)

data ModelImport = ModelImport [String]
    deriving (Eq, Show)

data MethodSymbolTable = MethodSymbolTable
    { returnType :: String
    , methodArgs :: [(String, String)] -- list of arguments
    } deriving (Show, Eq)

data CurrentState = CurrentState
    { currentClassName :: String
    , currentMethodName :: String
    } deriving (Eq)

extractReturnType :: SymbolTable -> String -> String -> String
extractReturnType symbolTable stModelName mName = do
    let matchingMethods = map snd $ filter (\x -> mName == (fst x)) (methods (modelSymbolTable) )
    if null matchingMethods
        then error ("No method found: " ++ stModelName ++ "::" ++ mName)
        else returnType $ matchingMethods!!0
  where
    modelSymbolTable =
        case getModelSymbolTable symbolTable stModelName of
             Just a -> a
             Nothing -> error ("No class found: " ++ stModelName)

extractMethodArgs :: SymbolTable -> String -> String -> [(String, String)]
extractMethodArgs symbolTable stModelName mName = do
    let matchingMethods = map snd $ filter (\x -> mName == (fst x)) (methods (modelSymbolTable) )
    if null matchingMethods
        then error ("No method found: " ++ stModelName ++ "::" ++ mName)
        else methodArgs $ matchingMethods!!0
  where
    modelSymbolTable = case getModelSymbolTable symbolTable stModelName of
                           Just a -> a
                           Nothing -> error ("No class found: " ++ stModelName)

methodExists :: SymbolTable -> String -> String -> Bool
methodExists symbolTable stModelName mName = do
    case getModelSymbolTable symbolTable stModelName of
        Just a -> do
            let matchingMethods = map snd $ filter (\x -> mName == (fst x)) (methods (a) )
            if null matchingMethods
                then False
                else True
        Nothing -> False

instanceVariableExists :: SymbolTable -> String -> String -> Bool
instanceVariableExists symbolTable stModelName varName = do
    case getModelSymbolTable symbolTable stModelName of
        Just a -> elem varName $ map fst $ publicVariables a
        Nothing -> False

instanceVariableType :: SymbolTable -> String -> String -> Maybe(String)
instanceVariableType symbolTable stModelName varName = do
    case getModelSymbolTable symbolTable stModelName of
        Just a -> do
            let matchingVars = filter (\var -> varName == fst var) $ publicVariables a
            if (length matchingVars > 0)
                then Just $ snd $ matchingVars!!0
                else Nothing
        Nothing -> Nothing

methodParamExists :: SymbolTable -> String -> String -> String -> Bool
methodParamExists symbolTable stModelName methodName varName = do
    case getModelSymbolTable symbolTable stModelName of
        Just a -> do
            let methodList = map (snd) (filter (\x -> fst x == (methodName)) (methods (a)))
            if null methodList
                then False
                else if (elem (varName) (map fst (methodArgs (methodList!!0))))
                     then True
                     else False
        Nothing -> False

getModelSymbolTable :: SymbolTable -> String -> Maybe ModelSymbolTable
getModelSymbolTable symbolTable symbolTablestModelName = do
    let matchingModels = filter (\x -> symbolTablestModelName == (stModelName x)) (modelSymbolTables symbolTable)
    if null matchingModels
        then Nothing
        else Just $ matchingModels!!0

-- todo combine if the class names are the same
combineSymbolTable :: SymbolTable -> SymbolTable -> SymbolTable
combineSymbolTable a b = SymbolTable []
  --ClassSymbolTable (className a) (publicVariables a ++ publicVariables b) (methods a ++ methods b)

combineSymbolTableList :: [SymbolTable] -> SymbolTable
combineSymbolTableList list = SymbolTable []
--do
  --if length list > 0
  --then foldl1 (\x y -> combineSymbolTable x y) list
  --else ClassSymbolTable "" [] []

combineModelSymbolTable :: ModelSymbolTable -> ModelSymbolTable -> ModelSymbolTable
combineModelSymbolTable a b = ModelSymbolTable (stModelName a) (stModelType a) (imports a ++ imports b) (publicVariables a ++ publicVariables b) (methods a ++ methods b)

combineModelSymbolTableList :: [ModelSymbolTable] -> ModelSymbolTable
combineModelSymbolTableList list = do
    if length list > 0
        then foldl1 (\x y -> combineModelSymbolTable x y) list
        else ModelSymbolTable "" UnknownModel [] [] []
